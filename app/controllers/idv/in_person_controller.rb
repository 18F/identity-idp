module Idv
  class InPersonController < ApplicationController
    before_action :render_404_unless_allowed
    before_action :confirm_two_factor_authenticated

    include Flow::FlowStateMachine

    FSM_SETTINGS = {
      step_url: :idv_in_person_step_url,
      final_url: :account_url,
      flow: Idv::Flows::InPersonFlow,
      analytics_id: 'In Person Proofing',
    }.freeze

    private

    def render_404_unless_allowed
      render_not_found unless in_person_proofing_allowed?
    end

    def in_person_proofing_allowed?
      IdentityConfig.store.in_person_proofing_enabled_issuers.include?(current_sp&.issuer)
    end
  end
end
