module Idv
  class ApiDocumentVerificationForm
    include ActiveModel::Model
    include ActionView::Helpers::TranslationHelper

    validates_presence_of :encryption_key
    validate :validate_image_urls
    validates_presence_of :document_capture_session
    validates_presence_of :front_image_iv
    validates_presence_of :back_image_iv
    validates_presence_of :selfie_image_iv, if: :liveness_checking_enabled?

    validate :throttle_if_rate_limited

    def initialize(params, liveness_checking_enabled:)
      @params = params
      @liveness_checking_enabled = liveness_checking_enabled
    end

    def submit
      throttled_else_increment

      FormResponse.new(
        success: valid?,
        errors: errors.messages,
        extra: {
          remaining_attempts: remaining_attempts,
        },
      )
    end

    def remaining_attempts
      return unless document_capture_session
      Throttler::RemainingCount.call(document_capture_session.user_id, :idv_acuant)
    end

    def liveness_checking_enabled?
      @liveness_checking_enabled
    end

    def document_capture_session_uuid
      params[:document_capture_session_uuid]
    end

    def document_capture_session
      @document_capture_session ||= DocumentCaptureSession.find_by(
        uuid: document_capture_session_uuid,
      )
    end

    private

    attr_reader :params

    def encryption_key
      params[:encryption_key]
    end

    def front_image_iv
      params[:front_image_iv]
    end

    def back_image_iv
      params[:back_image_iv]
    end

    def selfie_image_iv
      params[:selfie_image_iv]
    end

    def valid_url?(key)
      uri = params[key]
      parsed_uri = URI.parse(uri)
      parsed_uri.scheme.present? && parsed_uri.host.present?
    rescue URI::InvalidURIError
      false
    end

    def throttle_if_rate_limited
      return unless @throttled
      errors.add(:limit, t('errors.doc_auth.acuant_throttle'))
    end

    def throttled_else_increment
      return unless document_capture_session
      @throttled = Throttler::IsThrottledElseIncrement.call(
        document_capture_session.user_id,
        :idv_acuant,
      )
    end

    def validate_image_urls
      errors.add(:front_image_url, invalid_link) unless valid_url?(:front_image_url)
      errors.add(:back_image_url, invalid_link) unless valid_url?(:back_image_url)
      return if valid_url?(:selfie_image_url)
      errors.add(:selfie_image_url, invalid_link) unless liveness_checking_enabled?
    end

    def invalid_link
      t('doc_auth.errors.not_a_file')
    end
  end
end
