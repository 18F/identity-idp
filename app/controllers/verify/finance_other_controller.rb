module Verify
  class FinanceOtherController < ApplicationController
    include IdvStepConcern

    before_action :confirm_step_needed
    before_action :confirm_step_allowed

    helper_method :idv_finance_form
    helper_method :remaining_step_attempts
    helper_method :step_name

    def new
      @view_model = FinancialsNew.new
      analytics.track_event(Analytics::IDV_FINANCE_OTHER_VISIT)
    end

    private

    def step_name
      :financials
    end

    def confirm_step_needed
      redirect_to verify_phone_path if idv_session.financials_confirmation.try(:success?)
    end

    def idv_finance_form
      @_idv_finance_form ||= Idv::FinanceForm.new(idv_session.params)
    end
  end
end
