module Idv
  class ApiDocumentVerificationForm
    include ActiveModel::Model
    include ActionView::Helpers::TranslationHelper

    validates_presence_of :encryption_key
    validate :validate_image_urls
    validates_presence_of :document_capture_session
    validates_presence_of :front_image_iv
    validates_presence_of :back_image_iv

    validate :throttle_if_rate_limited

    def initialize(
      params,
      analytics:,
      irs_attempts_api_tracker:,
      flow_path: nil
    )
      @params = params
      @analytics = analytics
      @irs_attempts_api_tracker = irs_attempts_api_tracker
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

    def valid_url?(key)
      uri = params[key]
      parsed_uri = URI.parse(uri)
      parsed_uri.scheme.present? && parsed_uri.host.present?
    rescue URI::InvalidURIError
      false
    end

    def throttle_if_rate_limited
      return unless @throttled
      @analytics.throttler_rate_limit_triggered(throttle_type: :idv_doc_auth)
      @irs_attempts_api_tracker.idv_document_upload_rate_limited
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
          :front_image_url,
          invalid_link,
          type: :invalid_link,
        )
      end
      unless valid_url?(:back_image_url)
        errors.add(
          :back_image_url,
          invalid_link,
          type: :invalid_link,
        )
      end
    end

    def invalid_link
      t('doc_auth.errors.not_a_file')
    end
  end
end
