module Idv
  class ApiImageUploadForm
    include ActiveModel::Model
    include ActionView::Helpers::TranslationHelper

    validates_presence_of :front
    validates_presence_of :back
    validates_presence_of :selfie, if: :liveness_checking_enabled?
    validates_presence_of :document_capture_session

    validate :validate_images
    validate :throttle_if_rate_limited

    def initialize(params, liveness_checking_enabled:, service_provider:, analytics: nil,
                   uuid_prefix: nil)
      @params = params
      @liveness_checking_enabled = liveness_checking_enabled
      @service_provider = service_provider
      @analytics = analytics
      @readable = {}
      @uuid_prefix = uuid_prefix
    end

    def submit
      throttled_else_increment
      form_response = validate_form

      client_response = nil
      doc_pii_response = nil

      if form_response.success?
        client_response = post_images_to_client

        doc_pii_response = validate_pii_from_doc(client_response) if client_response.success?
      end

      determine_response(
        form_response: form_response,
        client_response: client_response,
        doc_pii_response: doc_pii_response,
      )
    end

    private

    attr_reader :params, :analytics, :service_provider, :form_response, :uuid_prefix

    def throttled_else_increment
      return unless document_capture_session
      @throttled = throttle.throttled_else_increment?
    end

    def validate_form
      response = Idv::DocAuthFormResponse.new(
        success: valid?,
        errors: errors,
        extra: extra_attributes,
      )

      analytics.idv_doc_auth_submitted_image_upload_form(**response.to_h)

      response
    end

    def post_images_to_client
      response = doc_auth_client.post_images(
        front_image: front.read,
        back_image: back.read,
        selfie_image: selfie&.read,
        liveness_checking_enabled: liveness_checking_enabled?,
        image_source: image_source,
        user_uuid: user_uuid,
        uuid_prefix: uuid_prefix,
      )
      response.extra.merge!(extra_attributes)
      response.extra[:state] = response.pii_from_doc[:state]
      response.extra[:state_id_type] = response.pii_from_doc[:state_id_type]

      update_analytics(response)

      response
    end

    def validate_pii_from_doc(client_response)
      response = Idv::DocPiiForm.new(
        pii: client_response.pii_from_doc,
        attention_with_barcode: client_response.attention_with_barcode?,
      ).submit
      response.extra.merge!(extra_attributes)

      analytics.idv_doc_auth_submitted_pii_validation(**response.to_h)

      store_pii(client_response) if client_response.success? && response.success?

      response
    end

    def extra_attributes
      @extra_attributes ||= {
        attempts: attempts,
        remaining_attempts: remaining_attempts,
        user_id: user_uuid,
        pii_like_keypaths: [[:pii]],
        flow_path: params[:flow_path],
      }
    end

    def remaining_attempts
      throttle.remaining_count if document_capture_session
    end

    def attempts
      throttle.attempts if document_capture_session
    end

    def determine_response(form_response:, client_response:, doc_pii_response:)
      # image validation failed
      return form_response unless form_response.success?

      # doc_pii validation failed
      return doc_pii_response if (doc_pii_response.present? && !doc_pii_response.success?)

      client_response
    end

    def liveness_checking_enabled?
      @liveness_checking_enabled
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

    def selfie
      as_readable(:selfie)
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
      if selfie.is_a? DataUrlImage::InvalidUrlFormatError
        errors.add(
          :selfie, t('doc_auth.errors.not_a_file'),
          type: :not_a_file
        )
      end
    end

    def throttle_if_rate_limited
      return unless @throttled
      track_event(Analytics::THROTTLER_RATE_LIMIT_TRIGGERED, throttle_type: :idv_doc_auth)
      errors.add(:limit, t('errors.doc_auth.throttled_heading'), type: :throttled)
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

    def as_readable(image_key)
      return @readable[image_key] if @readable.key?(image_key)
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

    def track_event(event, attributes = {})
      if analytics.present?
        analytics.track_event(
          event,
          attributes,
        )
      end
    end

    def update_analytics(client_response)
      add_costs(client_response)
      update_funnel(client_response)
      analytics.idv_doc_auth_submitted_image_upload_vendor(
        **client_response.to_h.merge(
          client_image_metrics: image_metadata,
          async: false,
          flow_path: params[:flow_path],
        ),
      )
    end

    def acuant_sdk_capture?
      image_metadata.dig(:front, :source) == 'acuant' &&
        image_metadata.dig(:back, :source) == 'acuant'
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
            service_provider: service_provider,
            liveness_checking_enabled: liveness_checking_enabled?).
        call(response)
    end

    def update_funnel(client_response)
      steps = %i[front_image back_image]
      steps << :selfie if liveness_checking_enabled?
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

    def throttle
      @throttle ||= Throttle.new(
        user: document_capture_session.user,
        throttle_type: :idv_doc_auth,
      )
    end
  end
end
