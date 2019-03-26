module Idv
  class RecoveryController < ApplicationController
    before_action :ensure_user_id_in_session

    include IdvSession # remove if we retire the non docauth LOA3 flow
    include Flow::FlowStateMachine

    FSM_SETTINGS = {
      step_url: :idv_recovery_step_url,
      final_url: :account_url,
      flow: Idv::Flows::RecoveryFlow,
      analytics_id: Analytics::IAL2_RECOVERY,
      view: 'idv/doc_auth',
    }.freeze

    private

    def ensure_user_id_in_session
      return if session[:ial2_recovery_user_id]
      result = Recover::ValidateRequestToken.new(token).call
      process_result(result)
    end

    def process_result(result)
      if result.success?
        session[:ial2_recovery_user_id] = result.extra[:for_user_id]
      else
        # other analytics are logged automatically by the flow state machine
        analytics.track_event(FSM_SETTINGS[:analytics_id], result.to_h)
        flash[:error] = t('errors.capture_doc.invalid_link')
        redirect_to root_url
      end
    end

    def token
      params[:token]
    end
  end
end
