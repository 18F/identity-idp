module Idv
  class InheritedProofingController < ApplicationController
    before_action :confirm_two_factor_authenticated
    before_action :redirect_if_pending_profile

    include IdvSession
    include Flow::FlowStateMachine
    include Idv::ThreatMetrixConcern

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

    def redirect_if_pending_profile
      return if sp_session[:ial2_strict] &&
                !IdentityConfig.store.gpo_allowed_for_strict_ial2
      redirect_to idv_gpo_verify_url if current_user.decorate.pending_profile_requires_verification?
    end
  end
end
