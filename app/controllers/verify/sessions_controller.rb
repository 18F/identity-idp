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
      process_step
    end

    private

    def process_step
      if step.complete
        redirect_to verify_finance_path
      elsif step.attempts_exceeded?
        redirect_to verify_fail_path
      elsif duplicate_ssn_error?
        flash[:error] = dupe_ssn_msg
        redirect_to verify_session_dupe_path
      else
        render :new
      end
    end

    def step
      @_step ||= Idv::ProfileStep.new(
        idv_form: idv_profile_form,
        idv_session: idv_session,
        analytics: analytics,
        params: profile_params
      )
    end

    def confirm_step_needed
      redirect_to verify_finance_path if idv_session.resolution.try(:success?)
    end

    def duplicate_ssn_error?
      form_errors = idv_profile_form.errors
      form_errors.include?(:ssn) && form_errors[:ssn].include?(dupe_ssn_msg)
    end

    def dupe_ssn_msg
      I18n.t('idv.errors.duplicate_ssn')
    end

    def idv_profile_form
      @_idv_profile_form ||= Idv::ProfileForm.new((idv_session.params || {}), current_user)
    end

    def profile_params
      params.require(:profile).permit(
        :first_name, :last_name, :dob, :ssn, :address1, :address2, :city, :state, :zipcode
      )
    end
  end
end
