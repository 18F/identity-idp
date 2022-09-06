module Idv
  class InheritedProofingController < ApplicationController
    include Flow::FlowStateMachine

    before_action :render_404_if_disabled
    layout 'inherited_proofing'

    FLOW_STATE_MACHINE_SETTINGS = {
      step_url: :idv_inherited_proofing_step_url,
      final_url: :idv_doc_auth_step_url,
      flow: Idv::Flows::InheritedProofingFlow,
      analytics_id: nil,
    }.freeze

    private

    def render_404_if_disabled
      render_not_found unless IdentityConfig.store.inherited_proofing_enabled
    end
  end
end
