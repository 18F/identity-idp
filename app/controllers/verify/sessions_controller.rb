module Verify
  class SessionsController < ApplicationController
    include IdvSession

    before_action :confirm_two_factor_authenticated
    before_action :confirm_idv_attempts_allowed
    before_action :confirm_idv_needed
    before_action :confirm_step_needed

    helper_method :idv_profile_form
    helper_method :remaining_idv_attempts
    helper_method :step_name
    helper_method :step

    def new
      @view_model = SessionsNew.new
      analytics.track_event(Analytics::IDV_BASIC_INFO_VISIT)
    end

    def create
      result = step.submit
      analytics.track_event(Analytics::IDV_BASIC_INFO_SUBMITTED, result.to_h)

      if result.success?
        redirect_to verify_finance_path
      else
        process_failure
      end
    end

    private

    def step_name
      :sessions
    end

    def confirm_step_needed
      redirect_to verify_finance_path if idv_session.profile_confirmation == true
    end

    def step
      @_step ||= Idv::ProfileStep.new(
        idv_form: idv_profile_form,
        idv_session: idv_session,
        params: profile_params
      )
    end

    def process_failure
      if step.attempts_exceeded?
        redirect_to verify_fail_path
      elsif step.duplicate_ssn?
        flash[:error] = t('idv.errors.duplicate_ssn')
        redirect_to verify_session_dupe_path
      else
        process_vendor_error
        render :new
      end
    end

    def process_vendor_error
      if step.form_valid_but_vendor_validation_failed?
        show_vendor_warning
        @view_model = SessionsNew.new(modal: 'warning')
      else
        @view_model = SessionsNew.new
      end
    end

    def show_vendor_warning
      presenter = VerificationWarningPresenter.new(step_name, remaining_idv_attempts)
      flash.now[:warning] = presenter.warning_message
    end

    def remaining_idv_attempts
      Idv::Attempter.idv_max_attempts - current_user.idv_attempts
    end

    def idv_profile_form
      @_idv_profile_form ||= Idv::ProfileForm.new((idv_session.params || {}), current_user)
    end

    def profile_params
      params.require(:profile).permit(*Pii::Attributes.members)
    end
  end
end
