module Idv
  class ApiImageUploadForm
    include ActiveModel::Model
    include ActionView::Helpers::TranslationHelper

    validates_presence_of :front
    validates_presence_of :back
    validates_presence_of :document_capture_session

    validate :validate_images
    validate :limit_if_rate_limited

    def initialize(params, service_provider:, analytics: nil,
                   uuid_prefix: nil, irs_attempts_api_tracker: nil, store_encrypted_images: false)
      @params = params
      @service_provider = service_provider
      @analytics = analytics
      @readable = {}
      @uuid_prefix = uuid_prefix
      @irs_attempts_api_tracker = irs_attempts_api_tracker
      @store_encrypted_images = store_encrypted_images
    end

    def submit
      form_response = validate_form

      client_response = nil
      doc_pii_response = nil

      if form_response.success?
        client_response = post_images_to_client

        if client_response.success?
          doc_pii_response = validate_pii_from_doc(client_response)
        end
      end

      response = determine_response(
        form_response: form_response,
        client_response: client_response,
        doc_pii_response: doc_pii_response,
      )

      track_event(response)

      response
    end

    private

    attr_reader :params, :analytics, :service_provider, :form_response, :uuid_prefix,
                :irs_attempts_api_tracker

    def increment_rate_limiter!
      return unless document_capture_session
      rate_limiter.increment!
    end

    def validate_form
      success = valid?
      increment_rate_limiter!
      track_rate_limited if rate_limited?

      response = Idv::DocAuthFormResponse.new(
        success: success,
        errors: errors,
        extra: extra_attributes,
      )

      analytics.idv_doc_auth_submitted_image_upload_form(**response.to_h)
      response
    end

    def post_images_to_client
      timer = JobHelpers::Timer.new

      response = timer.time('vendor_request') do
        doc_auth_client.post_images(
          front_image: front_image_bytes,
          back_image: back_image_bytes,
          image_source: image_source,
          user_uuid: user_uuid,
          uuid_prefix: uuid_prefix,
        )
      end

      response.extra.merge!(extra_attributes)
      response.extra[:state] = response.pii_from_doc[:state]
      response.extra[:state_id_type] = response.pii_from_doc[:state_id_type]

      update_analytics(
        client_response: response,
        vendor_request_time_in_ms: timer.results['vendor_request'],
      )

      response
    end

    def front_image_bytes
      @front_image_bytes ||= front.read
    end

    def back_image_bytes
      @back_image_bytes ||= back.read
    end

    def validate_pii_from_doc(client_response)
      response = Idv::DocPiiForm.new(
        pii: client_response.pii_from_doc,
        attention_with_barcode: client_response.attention_with_barcode?,
      ).submit
      response.extra.merge!(extra_attributes)

      analytics.idv_doc_auth_submitted_pii_validation(**response.to_h)

      if client_response.success? && response.success?
        store_pii(client_response)
        rate_limiter.reset!
      end

      response
    end

    def extra_attributes
      return @extra_attributes if defined?(@extra_attributes)
      @extra_attributes = {
        attempts: attempts,
        remaining_attempts: remaining_attempts,
        user_id: user_uuid,
        pii_like_keypaths: [[:pii]],
        flow_path: params[:flow_path],
      }

      if readable?(:front)
        @extra_attributes[:front_image_fingerprint] =
          Digest::SHA256.urlsafe_base64digest(front_image_bytes)
      end

      if readable?(:back)
        @extra_attributes[:back_image_fingerprint] =
          Digest::SHA256.urlsafe_base64digest(back_image_bytes)
      end

      @extra_attributes
    end

    def remaining_attempts
      rate_limiter.remaining_count if document_capture_session
    end

    def attempts
      rate_limiter.attempts if document_capture_session
    end

    def determine_response(form_response:, client_response:, doc_pii_response:)
      # image validation failed
      return form_response unless form_response.success?

      # doc_pii validation failed
      return doc_pii_response if (doc_pii_response.present? && !doc_pii_response.success?)

      client_response
    end

    def image_source
      if acuant_sdk_capture?
        DocAuth::ImageSources::ACUANT_SDK
      else
        DocAuth::ImageSources::UNKNOWN
      end
    end

    def front
      as_readable(:front)
    end

    def back
      as_readable(:back)
    end

    def document_capture_session
      @document_capture_session ||= DocumentCaptureSession.find_by(
        uuid: document_capture_session_uuid,
      )
    end

    def validate_images
      if front.is_a? DataUrlImage::InvalidUrlFormatError
        errors.add(
          :front, t('doc_auth.errors.not_a_file'),
          type: :not_a_file
        )
      end
      if back.is_a? DataUrlImage::InvalidUrlFormatError
        errors.add(
          :back, t('doc_auth.errors.not_a_file'),
          type: :not_a_file
        )
      end
    end

    def limit_if_rate_limited
      return unless document_capture_session
      return unless rate_limited?

      errors.add(:limit, t('errors.doc_auth.rate_limited_heading'), type: :rate_limited)
    end

    def track_rate_limited
      analytics.rate_limit_reached(limiter_type: :idv_doc_auth)
      irs_attempts_api_tracker.idv_document_upload_rate_limited
    end

    def document_capture_session_uuid
      params[:document_capture_session_uuid]
    end

    def doc_auth_client
      @doc_auth_client ||= DocAuthRouter.client(
        vendor_discriminator: document_capture_session_uuid,
        warn_notifier: proc { |attrs| analytics&.doc_auth_warning(**attrs) },
      )
    end

    def readable?(image_key)
      value = @readable[image_key]
      value && !value.is_a?(DataUrlImage::InvalidUrlFormatError)
    end

    def as_readable(image_key)
      return @readable[image_key] if readable?(image_key)
      value = params[image_key]
      @readable[image_key] = begin
        if value.respond_to?(:read)
          value
        elsif value.is_a? String
          DataUrlImage.new(value)
        end
      rescue DataUrlImage::InvalidUrlFormatError => error
        error
      end
    end

    def update_analytics(client_response:, vendor_request_time_in_ms:)
      add_costs(client_response)
      update_funnel(client_response)
      analytics.idv_doc_auth_submitted_image_upload_vendor(
        **client_response.to_h.merge(
          client_image_metrics: image_metadata,
          async: false,
          flow_path: params[:flow_path],
          vendor_request_time_in_ms: vendor_request_time_in_ms,
        ).merge(acuant_sdk_upgrade_ab_test_data),
      )
    end

    def store_encrypted_images_if_required
      return unless store_encrypted_images?

      encrypted_document_storage_writer.encrypt_and_write_document(
        front_image: front_image_bytes,
        front_image_content_type: front.content_type,
        back_image: back_image_bytes,
        back_image_content_type: back.content_type,
      )
    end

    def store_encrypted_images?
      @store_encrypted_images
    end

    def encrypted_document_storage_writer
      @encrypted_document_storage_writer ||= EncryptedDocumentStorage::DocumentWriter.new
    end

    def acuant_sdk_upgrade_ab_test_data
      return {} unless IdentityConfig.store.idv_acuant_sdk_upgrade_a_b_testing_enabled
      {
        acuant_sdk_upgrade_ab_test_bucket:
          AbTests::ACUANT_SDK.bucket(document_capture_session.uuid),
      }
    end

    def acuant_sdk_capture?
      image_metadata.dig(:front, :source) == Idp::Constants::Vendors::ACUANT &&
        image_metadata.dig(:back, :source) == Idp::Constants::Vendors::ACUANT
    end

    def image_metadata
      @image_metadata ||= params.permit(:front_image_metadata, :back_image_metadata).
        to_h.
        transform_values do |str|
          JSON.parse(str)
        rescue JSON::ParserError
          nil
        end.
        compact.
        transform_keys { |key| key.gsub(/_image_metadata$/, '') }.
        deep_symbolize_keys
    end

    def add_costs(response)
      Db::AddDocumentVerificationAndSelfieCosts.
        new(user_id: user_id,
            service_provider: service_provider).
        call(response)
    end

    def update_funnel(client_response)
      steps = %i[front_image back_image]
      steps.each do |step|
        Funnel::DocAuth::RegisterStep.new(user_id, service_provider&.issuer).
          call(step.to_s, :update, client_response.success?)
      end
    end

    def store_pii(client_response)
      document_capture_session.store_result_from_response(client_response)
    end

    def user_id
      document_capture_session&.user&.id
    end

    def user_uuid
      document_capture_session&.user&.uuid
    end

    def rate_limiter
      @rate_limiter ||= RateLimiter.new(
        user: document_capture_session.user,
        rate_limit_type: :idv_doc_auth,
      )
    end

    def rate_limited?
      rate_limiter.limited? if document_capture_session
    end

    def track_event(response)
      pii_from_doc = response.pii_from_doc || {}
      stored_image_result = store_encrypted_images_if_required

      irs_attempts_api_tracker.idv_document_upload_submitted(
        success: response.success?,
        document_state: pii_from_doc[:state],
        document_number: pii_from_doc[:state_id_number],
        document_issued: pii_from_doc[:state_id_issued],
        document_expiration: pii_from_doc[:state_id_expiration],
        document_front_image_filename: stored_image_result&.front_filename,
        document_back_image_filename: stored_image_result&.back_filename,
        document_image_encryption_key: stored_image_result&.encryption_key,
        first_name: pii_from_doc[:first_name],
        last_name: pii_from_doc[:last_name],
        date_of_birth: pii_from_doc[:dob],
        address: pii_from_doc[:address1],
        failure_reason: response.errors&.except(:hints)&.presence,
      )
    end
  end
end
