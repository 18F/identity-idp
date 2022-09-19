module Idv
  class InheritedProofingController < ApplicationController
    # TODO: Add InheritedProofingConcern
    include InheritedProofingConcern
    include Flow::FlowStateMachine

    #
    #include RenderConditionConcern

    #check_or_render_not_found -> { InPersonConfig.enabled_for_issuer?(current_sp&.issuer) }

    #before_action :confirm_two_factor_authenticated
    #before_action :redirect_unless_enrollment

    include IdvSession
    #include Idv::ThreatMetrixConcern

    #before_action :redirect_if_flow_completed
    #before_action :override_csp_for_threat_metrix
    #

    before_action :render_404_if_disabled

    FLOW_STATE_MACHINE_SETTINGS = {
      step_url: :idv_inherited_proofing_step_url,
      final_url: :idv_phone_url,
      flow: Idv::Flows::InheritedProofingFlow,
      analytics_id: nil,
    }.freeze

    def return_to_sp
      redirect_to return_to_sp_failure_to_proof_url(step: next_step, location: params[:location])
    end

    private

    def render_404_if_disabled
      render_not_found unless IdentityConfig.store.inherited_proofing_enabled
    end
  end
end
