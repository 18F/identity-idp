module Verify
  class FinanceController < ApplicationController
    include IdvStepConcern
    include IdvFailureConcern

    before_action :confirm_step_needed
    before_action :confirm_step_allowed

    def new
      @view_model = view_model
      analytics.track_event(Analytics::IDV_FINANCE_CCN_VISIT)
    end

    def create
      result = step.submit
      analytics.track_event(Analytics::IDV_FINANCE_CONFIRMATION, result.to_h)
      increment_step_attempts

      if result.success?
        handle_success
      else
        render_failure
        render_form
      end
    end

    private

    def step_name
      :financials
    end

    def confirm_step_needed
      redirect_to verify_address_path if idv_session.financials_confirmation == true
    end

    def view_model(error: nil)
      Verify::FinancialsNew.new(
        error: error,
        remaining_attempts: remaining_step_attempts,
        idv_form: idv_finance_form
      )
    end

    def idv_finance_form
      @_idv_finance_form ||= Idv::FinanceForm.new(idv_session.params)
    end

    def handle_success
      flash[:success] = t('idv.messages.personal_details_verified')
      redirect_to verify_address_url
    end

    def step
      @_step ||= Idv::FinancialsStep.new(
        idv_form: idv_finance_form,
        idv_session: idv_session,
        params: step_params
      )
    end

    def step_params
      params.require(:idv_finance_form).permit(:finance_type, *Idv::FinanceForm::FINANCE_TYPES)
    end

    def render_form
      if step_params[:finance_type] == 'ccn'
        render :new
      else
        render 'verify/finance_other/new'
      end
    end
  end
end
