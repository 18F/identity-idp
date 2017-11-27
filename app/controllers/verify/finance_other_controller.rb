module Verify
  class FinanceOtherController < ApplicationController
    include IdvStepConcern

    before_action :confirm_step_needed
    before_action :confirm_step_allowed

    def new
      @view_model = view_model
      analytics.track_event(Analytics::IDV_FINANCE_OTHER_VISIT)
    end

    private

    def step_name
      :financials
    end

    def confirm_step_needed
      redirect_to verify_phone_url if idv_session.financials_confirmation.try(:success?)
    end

    def view_model
      Verify::FinancialsNew.new(
        remaining_attempts: remaining_step_attempts,
        idv_form: idv_finance_form
      )
    end

    def idv_finance_form
      @_idv_finance_form ||= Idv::FinanceForm.new(idv_session.params)
    end
  end
end
