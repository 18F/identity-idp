module Verify
  class FinanceController < ApplicationController
    include IdvStepConcern
    include IdvFailureConcern

    before_action :confirm_step_needed
    before_action :confirm_step_allowed
    before_action :submit_idv_form, only: [:create]
    before_action :submit_idv_job, only: [:create]

    def new
      @view_model = view_model
      analytics.track_event(Analytics::IDV_FINANCE_CCN_VISIT)
    end

    def create
      result = step.submit
      analytics.track_event(Analytics::IDV_FINANCE_CONFIRMATION_VENDOR, result.to_h)
      increment_step_attempts

      if result.success?
        handle_success
      else
        render_failure
        render_form
      end
    end

    private

    def submit_idv_form
      result = idv_form.submit(step_params)
      analytics.track_event(Analytics::IDV_FINANCE_CONFIRMATION_FORM, result.to_h)

      return if result.success?

      @view_model = view_model
      render_form
    end

    def submit_idv_job
      SubmitIdvJob.new(
        vendor_validator_class: Idv::FinancialsValidator,
        idv_session: idv_session,
        vendor_params: vendor_params
      ).call
    end

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
        idv_form: idv_form
      )
    end

    def idv_form
      @_idv_form ||= Idv::FinanceForm.new(idv_session.params)
    end

    def handle_success
      flash[:success] = t('idv.messages.personal_details_verified')
      redirect_to verify_address_url
    end

    def step
      @_step ||= Idv::FinancialsStep.new(
        idv_form_params: idv_form.idv_params,
        idv_session: idv_session,
        vendor_validator_result: vendor_validator_result
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

    def vendor_params
      finance_type = idv_form.finance_type
      { finance_type => idv_form.idv_params[finance_type] }
    end
  end
end
