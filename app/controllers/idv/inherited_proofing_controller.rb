module Idv
  class InheritedProofingController < ApplicationController
    include Flow::FlowStateMachine

    FLOW_STATE_MACHINE_SETTINGS = {
      step_url: :idv_inherited_proofing_step_url,
      final_url: nil,
      flow: Idv::Flows::InheritedProofingFlow,
      analytics_id: nil,
    }.freeze
  end
end
