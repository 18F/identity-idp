module Verify
  class FinanceController < ApplicationController
    include IdvStepConcern

    before_action :confirm_step_needed
    before_action :confirm_step_allowed

    helper_method :idv_finance_form
    helper_method :remaining_step_attempts
    helper_method :step_name

    def new
      analytics.track_event(Analytics::IDV_FINANCE_CCN_VISIT)
    end

    def create
      result = step.submit
      analytics.track_event(Analytics::IDV_FINANCE_CONFIRMATION, result)
      increment_step_attempts

      if result[:success]
        redirect_to verify_phone_url
      elsif step_attempts_exceeded?
        redirect_to_fail_path
      else
        process_failure
      end
    end

    private

    def step_name
      :financials
    end

    def step
      @_step ||= Idv::FinancialsStep.new(
        idv_form: idv_finance_form,
        idv_session: idv_session,
        params: step_params
      )
    end

    def process_failure
      show_warning if step.form_valid_but_vendor_validation_failed?
      render_form
    end

    def step_params
      params.require(:idv_finance_form).permit(:finance_type, *Idv::FinanceForm::FINANCE_TYPES)
    end

    def confirm_step_needed
      redirect_to verify_phone_path if idv_session.financials_confirmation == true
    end

    def show_warning
      presenter = VerificationWarningPresenter.new(step_name, remaining_step_attempts)

      flash.now[:warning] = presenter.warning_message
      @modal = 'warning'
    end

    def render_form
      if step_params[:finance_type] == 'ccn'
        render :new
      else
        render 'verify/finance_other/new'
      end
    end

    def idv_finance_form
      @_idv_finance_form ||= Idv::FinanceForm.new(idv_session.params)
    end
  end
end
