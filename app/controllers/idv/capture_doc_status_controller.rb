module Idv
  class CaptureDocStatusController < ApplicationController
    before_action :confirm_two_factor_authenticated

    respond_to :json

    def show
      render(json: { redirect: redirect_url }.compact, status: status)
    end

    private

    def status
      @status ||= begin
        if !flow_session || !document_capture_session
          :unauthorized
        elsif document_capture_session.cancelled_at
          :gone
        elsif rate_limiter.limited?
          :too_many_requests
        elsif confirmed_barcode_attention_result? || user_has_establishing_in_person_enrollment?
          :ok
        elsif session_result.blank? || pending_barcode_attention_confirmation?
          :accepted
        elsif !session_result.success?
          :unauthorized
        else
          :ok
        end
      end
    end

    def redirect_url
      return unless flow_session && document_capture_session

      if rate_limiter.limited?
        idv_session_errors_throttled_url
      elsif user_has_establishing_in_person_enrollment?
        idv_in_person_url
      end
    end

    def flow_session
      user_session['idv/doc_auth']
    end

    def session_result
      return @session_result if defined?(@session_result)
      @session_result = document_capture_session.load_result ||
                        document_capture_session.load_doc_auth_async_result
    end

    def document_capture_session
      return @document_capture_session if defined?(@document_capture_session)
      @document_capture_session = DocumentCaptureSession.find_by uuid: document_capture_session_uuid
    end

    def document_capture_session_uuid
      flow_session[:document_capture_session_uuid]
    end

    def rate_limiter
      @rate_limiter ||= RateLimiter.new(
        user: document_capture_session.user,
        rate_limit_type: :idv_doc_auth,
      )
    end

    def user_has_establishing_in_person_enrollment?
      return false unless IdentityConfig.store.in_person_proofing_enabled
      current_user.establishing_in_person_enrollment.present?
    end

    def confirmed_barcode_attention_result?
      had_barcode_attention_result? && !document_capture_session.ocr_confirmation_pending?
    end

    def pending_barcode_attention_confirmation?
      had_barcode_attention_result? && document_capture_session.ocr_confirmation_pending?
    end

    def had_barcode_attention_result?
      if session_result
        flow_session[:had_barcode_attention_error] = session_result.attention_with_barcode?
      end

      flow_session[:had_barcode_attention_error]
    end
  end
end
