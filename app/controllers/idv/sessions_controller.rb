module Idv
  class SessionsController < ApplicationController
    include IdvSession
    include IdvFailureConcern
    include PersonalKeyConcern

    attr_reader :idv_form

    before_action :confirm_two_factor_authenticated, except: %i[success failure]
    before_action :confirm_idv_attempts_allowed, except: %i[success failure destroy]
    before_action :confirm_idv_needed, except: %i[destroy failure]
    before_action :confirm_step_needed, except: %i[success destroy]

    delegate :attempts_exceeded?, to: :step, prefix: true

    def new
      analytics.track_event(Analytics::IDV_BASIC_INFO_VISIT)
      set_idv_form
      @selected_state = idv_session.selected_jurisdiction
    end

    def create
      set_idv_form
      form_result = idv_form.submit(profile_params)
      analytics.track_event(Analytics::IDV_BASIC_INFO_SUBMITTED_FORM, form_result.to_h)
      return process_form_failure unless form_result.success?
      submit_proofing_attempt
    end

    def failure
      reason = params[:reason].to_sym
      render_idv_step_failure(:sessions, reason)
    end

    def destroy
      analytics.track_event(Analytics::IDV_VERIFICATION_ATTEMPT_CANCELLED)
      Idv::CancelVerificationAttempt.new(user: current_user).call
      idv_session.clear
      user_session.delete(:decrypted_pii)
      redirect_to idv_url
    end

    def success; end

    private

    def confirm_step_needed
      redirect_to idv_session_success_url if idv_session.profile_confirmation == true
    end

    def step
      @_step ||= Idv::ProfileStep.new(idv_session: idv_session)
    end

    def process_form_failure
      if (sp_name = decorated_session.sp_name) && idv_form.unsupported_jurisdiction?
        idv_form.add_sp_unsupported_jurisdiction_error(sp_name)
      end
      render :new
    end

    def submit_proofing_attempt
      idv_result = step.submit(profile_params.to_h)
      analytics.track_event(Analytics::IDV_BASIC_INFO_SUBMITTED_VENDOR, idv_result.to_h)
      redirect_to idv_session_success_url and return if idv_result.success?
      handle_proofing_failure
    end

    def handle_proofing_failure
      idv_session.previous_profile_step_params = profile_params.to_h
      redirect_to idv_session_failure_url(step.failure_reason)
    end

    def step_name
      :sessions
    end

    def remaining_step_attempts
      Idv::Attempter.idv_max_attempts - current_user.idv_attempts
    end

    def set_idv_form
      @idv_form ||= Idv::ProfileForm.new(
        user: current_user,
        previous_params: idv_session.previous_profile_step_params,
      )
    end

    def profile_params
      params.require(:profile).permit(Idv::ProfileForm::PROFILE_ATTRIBUTES)
    end

    def failure_url(reason)
      idv_session_failure_url(reason)
    end
  end
end
