module Verify
  class SessionsController < ApplicationController
    include IdvSession
    include IdvFailureConcern

    before_action :confirm_two_factor_authenticated, except: [:destroy]
    before_action :confirm_idv_attempts_allowed
    before_action :confirm_idv_needed
    before_action :confirm_step_needed, except: [:destroy]
    before_action :initialize_idv_session, only: [:create]
    before_action :submit_idv_form, only: [:create]
    before_action :submit_idv_job, only: [:create]

    delegate :attempts_exceeded?, to: :step, prefix: true

    def new
      user_session[:context] = 'idv'
      @view_model = view_model
      analytics.track_event(Analytics::IDV_BASIC_INFO_VISIT)
    end

    def create
      result = step.submit
      analytics.track_event(Analytics::IDV_BASIC_INFO_SUBMITTED_VENDOR, result.to_h)

      if result.success?
        process_success
      else
        process_failure
      end
    end

    def destroy
      idv_session = user_session[:idv]
      idv_session && idv_session.clear
      handle_idv_redirect
    end

    private

    def submit_idv_form
      result = idv_form.submit(profile_params)
      analytics.track_event(Analytics::IDV_BASIC_INFO_SUBMITTED_FORM, result.to_h)

      process_failure unless result.success?
    end

    def submit_idv_job
      SubmitIdvJob.new(
        vendor_validator_class: Idv::ProfileValidator,
        idv_session: idv_session,
        vendor_params: idv_session.vendor_params
      ).call
    end

    def step_name
      :sessions
    end

    def confirm_step_needed
      redirect_to verify_finance_path if idv_session.profile_confirmation == true
    end

    def step
      @_step ||= Idv::ProfileStep.new(
        idv_form_params: profile_params,
        idv_session: idv_session,
        vendor_validator_result: vendor_validator_result
      )
    end

    def handle_idv_redirect
      redirect_to account_path and return if current_user.personal_key.present?
      redirect_to manage_personal_key_path
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
      if idv_form.duplicate_ssn?
        flash[:error] = t('idv.errors.duplicate_ssn')
        redirect_to verify_session_dupe_path
      else
        render_failure
        render :new
      end
    end

    def view_model(error: nil)
      Verify::SessionsNew.new(
        error: error,
        remaining_attempts: remaining_idv_attempts,
        idv_form: idv_form
      )
    end

    def remaining_idv_attempts
      Idv::Attempter.idv_max_attempts - current_user.idv_attempts
    end

    def idv_form
      @_idv_form ||= Idv::ProfileForm.new((idv_session.params || {}), current_user)
    end

    def initialize_idv_session
      idv_session.params.merge!(profile_params)
      idv_session.applicant = idv_session.vendor_params
    end

    def profile_params
      params.require(:profile).permit(*Pii::Attributes.members)
    end
  end
end
