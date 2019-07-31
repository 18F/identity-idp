module Idv
  class CacController < ApplicationController
    before_action :render_404_if_disabled
    before_action :confirm_two_factor_authenticated

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
  end
end
