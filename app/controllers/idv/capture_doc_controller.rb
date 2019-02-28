module Idv
  class CaptureDocController < ApplicationController
    include Flow::FlowStateMachine
    before_action :set_user_from_token

    FSM_SETTINGS = {
      step_url: :idv_capture_doc_step_url,
      final_url: :root_url,
      flow: Idv::Flows::CaptureDocFlow,
      analytics_id: Analytics::CAPTURE_DOC,
    }.freeze

    def set_user_from_token
      return if session[:capture_user_id]
      user_id = CaptureDoc::FindUserId.call(params[:token])
      redirect_to root_url and return unless user_id
      session[:capture_user_id] = user_id
    end
  end
end
