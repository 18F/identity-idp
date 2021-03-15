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

    def initialize(params, liveness_checking_enabled:, issuer:, analytics: nil)
      @params = params
      @liveness_checking_enabled = liveness_checking_enabled
      @issuer = issuer
      @analytics = analytics
      @readable = {}
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

      return determine_response(
        form_response: form_response,
        client_response: client_response,
        doc_pii_response: doc_pii_response,
      )
    end

    private

    attr_reader :params, :analytics, :issuer, :form_response

    def throttled_else_increment
      return unless document_capture_session
      @throttled = Throttler::IsThrottledElseIncrement.call(
        document_capture_session.user_id,
        :idv_acuant,
      )
    end

    def validate_form
      response = Idv::DocAuthFormResponse.new(
        success: valid?,
        errors: errors.messages,
        extra: extra_attributes,
      )

      track_event(
        Analytics::IDV_DOC_AUTH_SUBMITTED_IMAGE_UPLOAD_FORM,
        response.to_h,
      )

      response
    end

    def post_images_to_client
      response = doc_auth_client.post_images(
        front_image: front.read,
        back_image: back.read,
        selfie_image: selfie&.read,
        liveness_checking_enabled: liveness_checking_enabled?,
      )
      response = response.merge(extra_attributes_response)

      update_analytics(response)

      response
    end

    def validate_pii_from_doc(client_response)
      response = Idv::DocPiiForm.new(client_response.pii_from_doc).submit
      response = response.merge(extra_attributes_response)

      track_event(
        Analytics::IDV_DOC_AUTH_SUBMITTED_PII_VALIDATION,
        response.to_h,
      )
      store_pii(client_response) if client_response.success? && response.success?

      response
    end

    def extra_attributes_response
      @extra_attributes_response ||= Idv::DocAuthFormResponse.new(
        success: true,
        errors: {},
        extra: extra_attributes,
      )
    end

    def extra_attributes
      @extra_attributes ||= {
        remaining_attempts: remaining_attempts,
        user_id: user_uuid,
      }
    end

    def remaining_attempts
      return nil unless document_capture_session
      Throttler::RemainingCount.call(document_capture_session.user_id, :idv_acuant)
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
      errors.add(:front, t('doc_auth.errors.not_a_file')) if front.is_a? URI::InvalidURIError
      errors.add(:back, t('doc_auth.errors.not_a_file')) if back.is_a? URI::InvalidURIError
      errors.add(:selfie, t('doc_auth.errors.not_a_file')) if selfie.is_a? URI::InvalidURIError
    end

    def throttle_if_rate_limited
      return unless @throttled
      track_event(Analytics::IDV_DOC_AUTH_RATE_LIMIT_TRIGGERED)
      errors.add(:limit, t('errors.doc_auth.acuant_throttle'))
    end

    def self.human_attribute_name(attr, options = {})
      I18n.t("doc_auth.headings.document_capture_#{attr}", options)
    end

    def document_capture_session_uuid
      params[:document_capture_session_uuid]
    end

    def doc_auth_client
      @doc_auth_client ||= DocAuthRouter.client
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
      rescue URI::InvalidURIError => error
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
      track_event(
        Analytics::IDV_DOC_AUTH_SUBMITTED_IMAGE_UPLOAD_VENDOR,
        client_response.to_h,
      )
    end

    def add_costs(response)
      Db::AddDocumentVerificationAndSelfieCosts.
        new(user_id: user_id,
            issuer: issuer,
            liveness_checking_enabled: liveness_checking_enabled?).
        call(response)
    end

    def update_funnel(client_response)
      steps = %i[front_image back_image]
      steps << :selfie if liveness_checking_enabled?
      steps.each do |step|
        Funnel::DocAuth::RegisterStep.new(user_id, issuer).
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
  end
end
