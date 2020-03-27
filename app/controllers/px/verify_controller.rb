module Px
  class VerifyController < ApplicationController
    before_action :confirm_two_factor_authenticated

    include Flow::FlowStateMachine

    FSM_SETTINGS = {
      step_url: :px_verify_step_url,
      final_url: :px_bank_account_url,
      flow: Px::Flows::VerifyFlow,
      analytics_id: Analytics::PX_VERIFY,
    }.freeze
  end
end
