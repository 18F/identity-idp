module Verify
  class SessionsController < ApplicationController
    include IdvSession

    before_action :confirm_two_factor_authenticated
    before_action :confirm_idv_attempts_allowed
    before_action :confirm_idv_needed
    before_action :confirm_step_needed

    helper_method :idv_profile_form
    helper_method :step

    def new
      @using_mock_vendor = idv_vendor.pick == :mock
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
        show_warning if step.form_valid_but_vendor_validation_failed?
        render :new
      end
    end

    def confirm_step_needed
      redirect_to verify_finance_path if idv_session.profile_confirmation == true
    end

    def show_warning
      flash.now[:warning] = t(
        'idv.modal.sessions.warning_html',
        accent: ActionController::Base.helpers.content_tag(
          :strong,
          t('idv.modal.sessions.warning_accent')
        )
      )
    end

    def idv_profile_form
      @_idv_profile_form ||= Idv::ProfileForm.new((idv_session.params || {}), current_user)
    end

    def profile_params
      params.require(:profile).permit(*Pii::Attributes.members)
    end
  end
end
