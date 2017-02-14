module Verify
  class SessionsController < ApplicationController
    include IdvSession

    before_action :confirm_two_factor_authenticated, except: [:destroy]
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
        process_success
      else
        process_failure
      end
    end

    def destroy
      user_session[:idv].clear
      redirect_to profile_path
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

    def process_success
      pii_msg = ActionController::Base.helpers.content_tag(
        :strong, t('idv.messages.sessions.pii')
      )

      flash[:success] = t('idv.messages.sessions.success',
                          pii_message: pii_msg)

      redirect_to verify_finance_path
    end

    def process_failure
      if step.duplicate_ssn?
        flash[:error] = t('idv.errors.duplicate_ssn')
        redirect_to verify_session_dupe_path
      else
        process_vendor_error
        render :new
      end
    end

    def process_vendor_error
      if step.attempts_exceeded?
        show_vendor_fail
      elsif step.form_valid_but_vendor_validation_failed?
        show_vendor_warning
      else
        @view_model = SessionsNew.new
      end
    end

    def show_vendor_fail
      @view_model = SessionsNew.new(modal: 'fail')
      @presenter = VerificationPresenter.new(step_name, @view_model.modal_type)
      flash.now[:error] = @presenter.fail_message
    end

    def show_vendor_warning
      @view_model = SessionsNew.new(modal: 'warning')
      @presenter = VerificationPresenter.new(
        step_name, @view_model.modal_type, remaining_step_attempts: remaining_idv_attempts
      )
      flash.now[:warning] = @presenter.warning_message
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
