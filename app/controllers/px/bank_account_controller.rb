module Px
  class BankAccountController < ApplicationController
    before_action :confirm_two_factor_authenticated

    include Flow::FlowStateMachine

    FSM_SETTINGS = {
      step_url: :px_bank_account_step_url,
      final_url: :account_url,
      flow: Px::Flows::BankAccountFlow,
      analytics_id: Analytics::PX_BANK_ACCOUNT,
    }.freeze
  end
end
