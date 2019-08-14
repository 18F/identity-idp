module Idv
  class CacController < ApplicationController
    before_action :render_404_if_disabled
    before_action :confirm_two_factor_authenticated
    before_action :cac_callback

    include Flow::FlowStateMachine

    FSM_SETTINGS = {
      step_url: :idv_cac_step_url,
      final_url: :idv_review_url,
      flow: Idv::Flows::CacFlow,
      analytics_id: Analytics::CAC_PROOFING,
    }.freeze

    def render_404_if_disabled
      render_not_found unless Figaro.env.cac_proofing_enabled == 'true'
    end

    def cac_callback
      return unless request.path == idv_cac_step_path(:present_cac) && params[:token]
      user_session['idv/cac']['Idv::Steps::Cac::PresentCacStep'] = true
      redirect_to idv_cac_step_path(:enter_info)
    end
  end
end
