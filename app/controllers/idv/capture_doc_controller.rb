module Idv
  class CaptureDocController < ApplicationController
    include Flow::FlowStateMachine
    before_action :ensure_user_id_in_session

    FSM_SETTINGS = {
      step_url: :idv_capture_doc_step_url,
      final_url: :root_url,
      flow: Idv::Flows::CaptureDocFlow,
      analytics_id: Analytics::CAPTURE_DOC,
    }.freeze

    private

    def ensure_user_id_in_session
      return if session[:doc_capture_user_id]
      result = CaptureDoc::ValidateRequestToken.new(token).call
      analytics.track_event(FSM_SETTINGS[:analytics_id], result.to_h)
      process_result(result)
    end

    def process_result(result)
      if result.success?
        session[:doc_capture_user_id] = result.extra[:for_user_id]
      else
        flash[:error] = t('errors.capture_doc.invalid_link')
        redirect_to root_url
      end
    end

    def token
      params[:token]
    end
  end
end
