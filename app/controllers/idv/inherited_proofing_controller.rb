module Idv
  class InheritedProofingController < ApplicationController
    include Flow::FlowStateMachine
    include IdvSession
    include InheritedProofingConcern

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
