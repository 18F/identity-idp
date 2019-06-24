module Idv
  class InPersonController < ApplicationController
    before_action :confirm_two_factor_authenticated

    include Flow::FlowStateMachine

    FSM_SETTINGS = {
      step_url: :idv_in_person_step_url,
      final_url: :account_url,
      flow: Idv::Flows::InPersonFlow,
      analytics_id: Analytics::IN_PERSON_PROOFING,
    }.freeze
  end
end
