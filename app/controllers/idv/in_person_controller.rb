module Idv
  class InPersonController < ApplicationController
    before_action :render_404_if_disabled
    before_action :confirm_two_factor_authenticated

    include Flow::FlowStateMachine

    FSM_SETTINGS = {
      step_url: :idv_in_person_step_url,
      final_url: :account_url,
      flow: Idv::Flows::InPersonFlow,
      analytics_id: 'In Person Proofing',
    }.freeze

    def render_404_if_disabled
      render_not_found unless IdentityConfig.store.in_person_proofing_enabled
    end
  end
end
