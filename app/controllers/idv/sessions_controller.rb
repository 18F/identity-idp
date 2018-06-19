module Idv
  class SessionsController < ApplicationController
    include IdvSession
    include IdvFailureConcern
    include PersonalKeyConcern

    before_action :confirm_two_factor_authenticated, except: [:destroy]
    before_action :confirm_idv_attempts_allowed, except: %i[destroy success failure]
    before_action :confirm_idv_needed
    before_action :confirm_step_needed, except: %i[destroy success]
    before_action :initialize_idv_session, only: [:create]
    before_action :refresh_if_not_ready, only: [:show]

    delegate :attempts_exceeded?, to: :step, prefix: true

    def new
      user_session[:context] = 'idv'
      @idv_form = idv_form
      @selected_state = user_session[:idv_jurisdiction]
      analytics.track_event(Analytics::IDV_BASIC_INFO_VISIT)
    end

    def create
      @idv_form = idv_form
      result = @idv_form.submit(profile_params)
      analytics.track_event(Analytics::IDV_BASIC_INFO_SUBMITTED_FORM, result.to_h)

      if result.success?
        Idv::Job.submit(idv_session, %i[resolution state_id])
        redirect_to idv_session_result_url
      else
        process_form_failure
      end
    end

    def show
      result = step.submit
      analytics.track_event(Analytics::IDV_BASIC_INFO_SUBMITTED_VENDOR, result.to_h)

      redirect_to idv_session_success_url and return if result.success?
      redirect_to idv_session_failure_url(idv_step_failure_reason)
    end

    def failure
      reason = params[:reason].to_sym
      render_dupe_ssn_failure and return if reason == :dupe_ssn
      render_idv_step_failure(:sessions, reason)
    end

    def success; end

    def destroy
      idv_session = user_session[:idv]
      idv_session&.clear
      handle_idv_redirect
    end

    private

    def confirm_step_needed
      redirect_to idv_session_success_url if idv_session.profile_confirmation == true
    end

    def step
      @_step ||= Idv::ProfileStep.new(
        idv_form_params: idv_session.params,
        idv_session: idv_session,
        vendor_validator_result: vendor_validator_result
      )
    end

    def handle_idv_redirect
      redirect_to account_url and return if current_user.personal_key.present?
      user_session[:personal_key] = create_new_code
      redirect_to manage_personal_key_url
    end

    def process_form_failure
      redirect_to idv_session_failure_url(:dupe_ssn) and return if @idv_form.duplicate_ssn?
      if (sp_name = decorated_session.sp_name) && @idv_form.unsupported_jurisdiction?
        @idv_form.add_sp_unsupported_jurisdiction_error(sp_name)
      end
      render :new
    end

    def render_dupe_ssn_failure
      presenter = Idv::SsnFailurePresenter.new(
        decorated_session: decorated_session,
        view_context: view_context
      )
      render_failure('shared/_failure', presenter)
    end

    def step_name
      :sessions
    end

    def remaining_step_attempts
      Idv::Attempter.idv_max_attempts - current_user.idv_attempts
    end

    def idv_form
      @_idv_form ||= Idv::ProfileForm.new((idv_session.params || {}), current_user)
    end

    def initialize_idv_session
      idv_session.params = profile_params.to_h
      idv_session.params[:state_id_jurisdiction] = profile_params[:state]
      idv_session.applicant = idv_session.vendor_params
    end

    def profile_params
      params.require(:profile).permit(Idv::ProfileForm::PROFILE_ATTRIBUTES)
    end

    def failure_url(reason)
      idv_session_failure_url(reason)
    end
  end
end
