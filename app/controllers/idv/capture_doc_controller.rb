module Idv
  class CaptureDocController < ApplicationController
    before_action :ensure_user_id_in_session
    before_action :add_unsafe_eval_to_capture_steps

    include Flow::FlowStateMachine

    FSM_SETTINGS = {
      step_url: :idv_capture_doc_step_url,
      final_url: :root_url,
      flow: Idv::Flows::CaptureDocFlow,
      analytics_id: Analytics::CAPTURE_DOC,
    }.freeze

    private

    def ensure_user_id_in_session
      return if session[:doc_capture_user_id] && token.blank?
      result = CaptureDoc::ValidateRequestToken.new(token).call
      analytics.track_event(FSM_SETTINGS[:analytics_id], result.to_h)
      process_result(result)
    end

    def add_unsafe_eval_to_capture_steps
      return unless %w[
        front_image
        back_image
        mobile_front_image
        mobile_back_image
        selfie
        document_capture
      ].include?(current_step)

      # required to run wasm until wasm-eval is available
      SecureHeaders.append_content_security_policy_directives(
        request,
        script_src: ['\'unsafe-eval\''],
      )
    end

    def process_result(result)
      if result.success?
        reset_session
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
