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

    def initialize(params, liveness_checking_enabled:, analytics:, flow_path: nil)
      @params = params
      @liveness_checking_enabled = liveness_checking_enabled
      @analytics = analytics
      @flow_path = flow_path
    end

    def submit
      throttled_else_increment

      response = FormResponse.new(
        success: valid?,
        errors: errors,
        extra: {
          remaining_attempts: remaining_attempts,
          flow_path: @flow_path,
        },
      )

      @analytics.idv_doc_auth_submitted_image_upload_form(
        **response.to_h,
      )

      response
    end

    def remaining_attempts
      return unless document_capture_session
      throttle.remaining_count
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
      @analytics.track_event(
        Analytics::THROTTLER_RATE_LIMIT_TRIGGERED,
        throttle_type: :idv_doc_auth,
      )
      errors.add(:limit, t('errors.doc_auth.throttled_heading'), type: :throttled)
    end

    def throttled_else_increment
      return unless document_capture_session
      @throttled = throttle.throttled_else_increment?
    end

    def throttle
      @throttle ||= Throttle.new(
        user: document_capture_session.user,
        throttle_type: :idv_doc_auth,
      )
    end

    def validate_image_urls
      unless valid_url?(:front_image_url)
        errors.add(
          :front_image_url, invalid_link,
          type: :invalid_link
        )
      end
      unless valid_url?(:back_image_url)
        errors.add(
          :back_image_url, invalid_link,
          type: :invalid_link
        )
      end
      return if valid_url?(:selfie_image_url)
      if liveness_checking_enabled?
        errors.add(
          :selfie_image_url, invalid_link,
          type: :invalid_link
        )
      end
    end

    def invalid_link
      t('doc_auth.errors.not_a_file')
    end
  end
end
