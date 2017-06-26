module Verify
  class SessionsController < ApplicationController
    include IdvSession
    include IdvFailureConcern
    include DelegatedProofingConcern

    before_action :confirm_two_factor_authenticated, except: [:destroy]
    before_action :confirm_idv_attempts_allowed
    before_action :confirm_idv_needed
    before_action :confirm_step_needed, except: [:destroy]

    delegate :attempts_exceeded?, to: :step, prefix: true

    def new
      user_session[:context] = 'idv'
      @view_model = view_model
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
      idv_session = user_session[:idv]
      idv_session && idv_session.clear
      handle_idv_redirect
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

      if delegated_proofing_session?
        redirect_to verify_review_path
      else
        redirect_to verify_finance_path
      end
    end

    def process_failure
      if step.duplicate_ssn?
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
        idv_form: idv_profile_form
      )
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
