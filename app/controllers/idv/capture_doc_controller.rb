module Idv
  class CaptureDocController < ApplicationController
    before_action :ensure_user_id_in_session

    include Flow::FlowStateMachine
    include Idv::DocumentCaptureConcern

    FSM_SETTINGS = {
      step_url: :idv_capture_doc_step_url,
      final_url: :root_url,
      flow: Idv::Flows::CaptureDocFlow,
      analytics_id: Analytics::CAPTURE_DOC,
    }.freeze

    private

    def ensure_user_id_in_session
      return if session[:doc_capture_user_id] &&
                token.blank? &&
                document_capture_session_uuid.blank?

      result = CaptureDoc::ValidateDocumentCaptureSession.new(document_capture_session_uuid).call

      analytics.track_event(FSM_SETTINGS[:analytics_id], result.to_h)
      process_result(result)
    end

    def process_result(result)
      if result.success?
        reset_session
        session[:doc_capture_user_id] = result.extra[:for_user_id]
        session[:document_capture_session_uuid] = document_capture_session_uuid
        update_sp_session_with_result(result)
      else
        flash[:error] = t('errors.capture_doc.invalid_link')
        redirect_to root_url
      end
    end

    def update_sp_session_with_result(result)
      session[:sp] ||= {}
      session[:sp][:ial2_strict] = result.extra[:ial2_strict]
      session[:sp][:issuer] = result.extra[:sp_issuer]
    end

    def token
      params[:token]
    end

    def document_capture_session_uuid
      params['document-capture-session']
    end
  end
end
