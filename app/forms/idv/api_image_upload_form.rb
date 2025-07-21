# frozen_string_literal: true

module Idv
  class ApiImageUploadForm
    include ActiveModel::Model
    include ActionView::Helpers::TranslationHelper

    validates_presence_of :document_capture_session

    validate :needed_images_present
    validate :validate_images
    validate :validate_duplicate_images, if: :image_resubmission_check?
    validate :limit_if_rate_limited

    def initialize(
      params,
      acuant_sdk_upgrade_ab_test_bucket:,
      attempts_api_tracker:,
      service_provider:,
      analytics: nil,
      liveness_checking_required: false,
      uuid_prefix: nil
    )
      @params = params
      @acuant_sdk_upgrade_ab_test_bucket = acuant_sdk_upgrade_ab_test_bucket
      @analytics = analytics
      @attempts_api_tracker = attempts_api_tracker
      @readable = {}
      @service_provider = service_provider
      @uuid_prefix = uuid_prefix
      @liveness_checking_required = liveness_checking_required
    end

    def submit
      form_response = validate_form

      client_response = nil
      doc_pii_response = nil
      mrz_response = nil

      if form_response.success?
        client_response = post_images_to_client

        document_capture_session.update!(
          last_doc_auth_result: client_response.extra[:doc_auth_result],
        )

        if client_response.success?
          doc_pii_response = validate_pii_from_doc(client_response)

          if doc_pii_response.success? && passport_requested? && passport_submittal
            mrz_response = validate_mrz(client_response)
          end
        end
      end

      response = determine_response(
        form_response:,
        client_response:,
        doc_pii_response:,
        mrz_response:,
      )

      # Store PII and MRZ status after all validations are complete
      if client_response&.success? && doc_pii_response&.success?
        store_pii(client_response, mrz_response)
      end

      # if there is no client_response, there was no submission attempt
      if doc_escrow_enabled? && client_response
        pii_from_doc = client_response.pii_from_doc.to_h || {}

        attempts_api_tracker.idv_document_upload_submitted(
          **doc_escrow_images,
          success: response.success?,
          document_state: pii_from_doc[:state],
          document_number: pii_from_doc[:state_id_number],
          document_issued: pii_from_doc[:state_id_issued],
          document_expiration: pii_from_doc[:state_id_expiration],
          first_name: pii_from_doc[:first_name],
          last_name: pii_from_doc[:last_name],
          date_of_birth: pii_from_doc[:dob],
          address1: pii_from_doc[:address1],
          address2: pii_from_doc[:address2],
          city: pii_from_doc[:city],
          state: pii_from_doc[:state],
          zip: pii_from_doc[:zip],
          failure_reason: failure_reason(response),
        )
      end

      failed_fingerprints = store_failed_images(client_response, doc_pii_response)
      response.extra[:failed_image_fingerprints] = failed_fingerprints
      abandon_any_ipp_progress
      response
    end

    private

    attr_reader :acuant_sdk_upgrade_ab_test_bucket,
                :analytics,
                :attempts_api_tracker,
                :form_response,
                :liveness_checking_required,
                :params,
                :service_provider,
                :uuid_prefix

    def abandon_any_ipp_progress
      user_id && User.find(user_id).establishing_in_person_enrollment&.cancel
    end

    def failure_reason(response)
      if response.respond_to?(:vendor_errors)
        response.vendor_errors.presence ||
          attempts_api_tracker.parse_failure_reason(response)
      else
        attempts_api_tracker.parse_failure_reason(response)
      end
    end

    def increment_rate_limiter!
      return unless document_capture_session
      rate_limiter.increment!
    end

    def validate_form
      success = valid?
      increment_rate_limiter!

      response = Idv::DocAuthFormResponse.new(
        success: success,
        errors: errors,
        extra: extra_attributes,
      )

      analytics.idv_doc_auth_submitted_image_upload_form(**response)
      track_rate_limited if rate_limited?
      track_upload_attempt(response)

      response
    end

    def track_upload_attempt(response)
      return unless doc_escrow_enabled?

      attempts_api_tracker.idv_document_uploaded(
        **doc_escrow_images,
        success: response.success?,
        failure_reason: attempts_api_tracker.parse_failure_reason(response),
      )
    end

    def doc_escrow_enabled?
      IdentityConfig.store.doc_escrow_enabled
    end

    def post_images_to_client
      timer = JobHelpers::Timer.new

      response = timer.time('vendor_request') do
        doc_auth_client.post_images(
          **images_metadata.submittable_images,
          image_source: image_source,
          images_cropped: acuant_sdk_autocaptured_id?,
          user_uuid: user_uuid,
          uuid_prefix: uuid_prefix,
          liveness_checking_required: liveness_checking_required,
          document_type: document_type,
        )
      end

      response.extra.merge!(extra_attributes)
      pii_hash = response.pii_from_doc.to_h
      response.extra[:state] = pii_hash[:state]
      response.extra[:id_doc_type] = pii_hash[:id_doc_type]
      response.extra[:country] = pii_hash[:issuing_country_code]

      update_analytics(
        client_response: response,
        vendor_request_time_in_ms: timer.results['vendor_request'],
      )
      response
    end

    def document_type
      return nil if document_capture_session.nil?

      @document_type ||= passport_requested? \
        ? 'Passport' : 'DriversLicense'
    end

    def validate_pii_from_doc(client_response)
      response = Idv::DocPiiForm.new(
        pii: client_response.pii_from_doc.to_h,
        attention_with_barcode: client_response.attention_with_barcode?,
      ).submit
      response.extra.merge!(extra_attributes)
      side_classification = doc_side_classification(client_response)
      response_with_classification =
        response.to_h.merge(side_classification)
          .merge(id_doc_type: client_response.pii_from_doc.id_doc_type)

      analytics.idv_doc_auth_submitted_pii_validation(**response_with_classification)

      response
    end

    def validate_mrz(client_response)
      id_type = client_response.pii_from_doc.id_doc_type
      unless id_type == 'passport'
        return DocAuth::Response.new(
          success: false,
          errors: { passport: "Cannot validate MRZ for id type: #{id_type}" },
        )
      end
      mrz_client = document_capture_session.doc_auth_vendor == 'mock' ?
                     DocAuth::Mock::DosPassportApiClient.new(client_response) :
                     DocAuth::Dos::Requests::MrzRequest.new(mrz: client_response.pii_from_doc.mrz)
      response = mrz_client.fetch

      analytics.idv_dos_passport_verification(
        document_type:,
        remaining_submit_attempts:,
        submit_attempts:,
        user_id: user_uuid,
        response: response.extra[:response],
        success: response.success?,
      )

      response.extra.merge!(extra_attributes)
      response
    end

    def doc_side_classification(client_response)
      side_info = {}.merge(client_response&.extra&.[](:classification_info) || {})
      side_info.transform_keys(&:downcase).symbolize_keys
      {
        classification_info: side_info,
      }
    end

    def extra_attributes
      return @extra_attributes if defined?(@extra_attributes) &&
                                  @extra_attributes&.dig('submit_attempts') == submit_attempts
      @extra_attributes = {
        submit_attempts: submit_attempts,
        remaining_submit_attempts: remaining_submit_attempts,
        user_id: user_uuid,
        pii_like_keypaths: DocPiiForm.pii_like_keypaths(document_type: document_type),
        flow_path: params[:flow_path],
      }

      images.each do |image|
        @extra_attributes[image.extra_attribute_key] = image.fingerprint
      end

      @extra_attributes[:liveness_checking_required] = liveness_checking_required
      @extra_attributes[:document_type] = document_type
      @extra_attributes
    end

    def selfie_image_fingerprint
      return unless liveness_checking_required

      images_metadata.selfie&.fingerprint
    end

    def remaining_submit_attempts
      rate_limiter.remaining_count if document_capture_session
    end

    def submit_attempts
      rate_limiter.attempts if document_capture_session
    end

    def processed_selfie_attempts_data
      return {} if document_capture_session.nil? || !liveness_checking_required

      captured_result = document_capture_session&.load_result
      processed_selfie_count = selfie_image_fingerprint ? 1 : 0
      past_selfie_count = (captured_result&.failed_selfie_image_fingerprints || []).length
      { selfie_attempts: past_selfie_count + processed_selfie_count }
    end

    def determine_response(form_response:, client_response:, doc_pii_response:, mrz_response:)
      # image validation failed
      return form_response unless form_response.success?

      # doc_pii validation failed
      return doc_pii_response if doc_pii_response.present? && !doc_pii_response.success?

      # mrz validation failed
      return mrz_response if mrz_response.present? && !mrz_response.success?

      client_response
    end

    def image_source
      if acuant_sdk_captured_id?
        DocAuth::ImageSources::ACUANT_SDK
      else
        DocAuth::ImageSources::UNKNOWN
      end
    end

    def needed_images_present
      errs = images_metadata.needed_images_present?(liveness_checking_required)

      errs.each do |k, v|
        errors.add(k, t('errors.messages.blank'), type: v[:type])
      end
    end

    def images
      images_metadata.images
    end

    def images_metadata
      @images_metadata ||= IdvImages.new(params)
    end

    def doc_escrow_images
      return {} unless service_provider&.attempts_api_enabled?

      images_metadata.attempts_file_data
    end

    def passport_submittal
      images_metadata.passport_submittal
    end

    def document_capture_session
      @document_capture_session ||= DocumentCaptureSession.find_by(
        uuid: document_capture_session_uuid,
      )
    end

    def validate_images
      images.each do |image|
        if image.value.is_a? DataUrlImage::InvalidUrlFormatError
          errors.add(
            image.type, t('doc_auth.errors.not_a_file'),
            type: :not_a_file
          )
        end
      end

      if !IdentityConfig.store.doc_auth_selfie_desktop_test_mode &&
         liveness_checking_required && !acuant_sdk_captured?
        errors.add(
          :selfie, t('doc_auth.errors.not_a_file'),
          type: :not_a_file
        )
      end
    end

    def validate_duplicate_images
      capture_result = document_capture_session&.load_result
      return unless capture_result
      error_sides = []
      images.each do |image|
        if capture_result&.send(:"failed_#{image.type}_image?", image.fingerprint)
          errors.add(
            image.type,
            t('doc_auth.errors.doc.resubmit_failed_image'),
            type: :duplicate_image,
          )
          if image.type == :selfie
            analytics.idv_doc_auth_failed_image_resubmitted(
              side: 'selfie', **extra_attributes,
            )
            next
          end
          error_sides << image.type.to_s
        end
      end

      unless error_sides.empty?
        analytics.idv_doc_auth_failed_image_resubmitted(
          side: error_sides.length == 2 ? 'both' : error_sides[0], **extra_attributes,
        )
      end
    end

    def limit_if_rate_limited
      return unless rate_limited?

      errors.add(:limit, t('doc_auth.errors.rate_limited_heading'), type: :rate_limited)
    end

    def track_rate_limited
      analytics.rate_limit_reached(
        limiter_type: :idv_doc_auth,
        user_id: user_uuid,
      )
      attempts_api_tracker.idv_rate_limited(limiter_type: :idv_doc_auth)
    end

    def document_capture_session_uuid
      params[:document_capture_session_uuid]
    end

    def doc_auth_client
      @doc_auth_client ||= DocAuthRouter.client(
        vendor: document_capture_session.doc_auth_vendor,
        warn_notifier: proc do |attrs|
          analytics&.doc_auth_warning(
            **attrs,
          )
        end,
      )
    end

    def update_analytics(client_response:, vendor_request_time_in_ms:)
      add_costs(client_response)
      update_funnel(client_response)
      is_state_id = client_response.pii_from_doc.is_a?(Pii::StateId)
      birth_year = client_response.pii_from_doc&.dob&.to_date&.year
      zip_code = is_state_id ? client_response.pii_from_doc&.zipcode&.to_s&.strip&.slice(0, 5) : nil
      issue_year = nil
      if is_state_id
        issue_year = client_response.pii_from_doc&.state_id_issued&.to_date&.year
      else
        issue_year = client_response.pii_from_doc&.passport_issued&.to_date&.year
      end
      analytics.idv_doc_auth_submitted_image_upload_vendor(
        **client_response.to_h.merge(
          birth_year: birth_year,
          client_image_metrics: image_metadata,
          async: false,
          flow_path: params[:flow_path],
          vendor_request_time_in_ms: vendor_request_time_in_ms,
          zip_code: zip_code,
          issue_year: issue_year,
        ).except(:classification_info)
        .merge(acuant_sdk_upgrade_ab_test_data)
        .merge(processed_selfie_attempts_data),
      )
    end

    def acuant_sdk_upgrade_ab_test_data
      {
        acuant_sdk_upgrade_ab_test_bucket:,
      }
    end

    def acuant_sdk_captured?
      acuant_sdk_captured_id? &&
        (liveness_checking_required ? acuant_sdk_captured_selfie? : true)
    end

    def acuant_sdk_captured_id?
      if passport_submittal
        image_metadata.dig(:passport, :source) == Idp::Constants::Vendors::ACUANT
      else
        image_metadata.dig(:front, :source) == Idp::Constants::Vendors::ACUANT &&
          image_metadata.dig(:back, :source) == Idp::Constants::Vendors::ACUANT
      end
    end

    def acuant_sdk_captured_selfie?
      image_metadata.dig(:selfie, :source) == Idp::Constants::Vendors::ACUANT
    end

    def acuant_sdk_autocaptured_id?
      if passport_submittal
        image_metadata.dig(:passport, :acuantCaptureMode) == 'AUTO'
      else
        image_metadata.dig(:front, :acuantCaptureMode) == 'AUTO' &&
          image_metadata.dig(:back, :acuantCaptureMode) == 'AUTO'
      end
    end

    def image_metadata
      @image_metadata ||= params
        .permit(:front_image_metadata, :back_image_metadata,
                :passport_image_metadata, :selfie_image_metadata).to_h
        .transform_values do |str|
          JSON.parse(str)
        rescue JSON::ParserError
          nil
        end
        .compact
        .transform_keys { |key| key.gsub(/_image_metadata$/, '') }
        .deep_symbolize_keys
    end

    def add_costs(response)
      Db::AddDocumentVerificationAndSelfieCosts
        .new(user_id: user_id,
             service_provider: service_provider,
             liveness_checking_enabled: liveness_checking_required)
        .call(response)
    end

    def update_funnel(client_response)
      steps = %i[front_image back_image]
      steps = %i[passport_image] if passport_submittal
      steps.each do |step|
        Funnel::DocAuth::RegisterStep.new(user_id, service_provider&.issuer)
          .call(step.to_s, :update, client_response.success?)
      end
    end

    def store_pii(client_response, mrz_response)
      document_capture_session.store_result_from_response(client_response, mrz_response:)
    end

    def user_id
      document_capture_session&.user&.id
    end

    def user_uuid
      document_capture_session&.user&.uuid
    end

    def passport_requested?
      !!document_capture_session&.passport_requested?
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

    ##
    # Store failed image fingerprints in document_capture_session_result
    # when client_response is not successful and not a network error
    # ( http status except handled status 438, 439, 440 ) or doc_pii_response is not successful.
    # @param [Object] client_response
    # @param [Object] doc_pii_response
    # @return [Object] latest failed fingerprints
    def store_failed_images(client_response, doc_pii_response)
      unless image_resubmission_check?
        return {
          front: [],
          back: [],
          passport: [],
          selfie: [],
        }
      end
      # doc auth failed due to non network error or doc_pii is not valid
      failed_front_fingerprint = nil
      failed_back_fingerprint = nil
      failed_passport_fingerprint = nil

      if client_response && !client_response.success? && !client_response.network_error?
        errors_hash = client_response.errors&.to_h || {}

        if errors_hash[:front] || errors_hash[:back] || errors_hash[:passport]
          if errors_hash[:front]
            failed_front_fingerprint = extra_attributes[:front_image_fingerprint]
          end
          if errors_hash[:back]
            failed_back_fingerprint = extra_attributes[:back_image_fingerprint]
          end
          if errors_hash[:passport]
            failed_passport_fingerprint = extra_attributes[:passport_image_fingerprint]
          end
        elsif !client_response.doc_auth_success?
          failed_front_fingerprint = extra_attributes[:front_image_fingerprint]
          failed_back_fingerprint = extra_attributes[:back_image_fingerprint]
          failed_passport_fingerprint = extra_attributes[:passport_image_fingerprint]
        end
        document_capture_session.store_failed_auth_data(
          front_image_fingerprint: failed_front_fingerprint,
          back_image_fingerprint: failed_back_fingerprint,
          passport_image_fingerprint: failed_passport_fingerprint,
          selfie_image_fingerprint: extra_attributes[:selfie_image_fingerprint],
          doc_auth_success: client_response.doc_auth_success?,
          selfie_status: client_response.selfie_status,
        )
      elsif doc_pii_response && !doc_pii_response.success?
        document_capture_session.store_failed_auth_data(
          front_image_fingerprint: extra_attributes[:front_image_fingerprint],
          back_image_fingerprint: extra_attributes[:back_image_fingerprint],
          passport_image_fingerprint: failed_passport_fingerprint,
          selfie_image_fingerprint: extra_attributes[:selfie_image_fingerprint],
          doc_auth_success: client_response.doc_auth_success?,
          selfie_status: client_response.selfie_status,
        )
      end
      # retrieve updated data from session
      captured_result = document_capture_session&.load_result
      {
        front: captured_result&.failed_front_image_fingerprints || [],
        back: captured_result&.failed_back_image_fingerprints || [],
        passport: captured_result&.failed_passport_image_fingerprints || [],
        selfie: captured_result&.failed_selfie_image_fingerprints || [],
      }
    end

    def image_resubmission_check?
      IdentityConfig.store.doc_auth_check_failed_image_resubmission_enabled
    end
  end
end
