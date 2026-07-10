# frozen_string_literal: true

module Idv
  class EnterDobSsnController < ApplicationController
    include AvailabilityConcern
    include IdvStepConcern
    include StepIndicatorConcern
    include ProofingAgentConcern
    include Steps::ThreatMetrixStepHelper
    include ThreatMetrixConcern

    before_action :confirm_two_factor_authenticated
    before_action :confirm_verification_needed
    before_action :move_agent_proofed_user_pii_to_idv_session
    before_action :override_csp_for_threat_metrix,
                  if: -> {
                    FeatureManagement.proofing_agent_device_profiling_collecting_enabled?
                  }

    def new
      @dob_ssn_form = Idv::DobSsnForm.new(idv_session.applicant)
      analytics.idv_proofing_agent_user_confirmation_visited(**proofing_agent_analytics)

      render :new, locals: threatmetrix_view_variables
    end

    def create
      @dob_ssn_form = Idv::DobSsnForm.new(idv_session.applicant)

      form_response = @dob_ssn_form.submit(
        ssn: dob_ssn_params[:ssn],
        dob: dob_ssn_params[:dob],
      )
      idv_session.proofing_agent_match = form_response.success?

      analytics.idv_proofing_agent_user_confirmation_submitted(
        **proofing_agent_analytics,
        success: form_response.success?,
        dob_match: @dob_ssn_form.dob_match?,
        ssn_match: @dob_ssn_form.ssn_match?,
        dob_and_ssn_match: @dob_ssn_form.ssn_match? && @dob_ssn_form.dob_match?,
      )

      if form_response.success?
        if FeatureManagement.proofing_agent_device_profiling_collecting_enabled?
          ::ProofingAgentThreatMetrixJob.perform_now(**tmx_job_attrs)
        end
        return redirect_to idv_enter_password_url
      else
        flash.now[:error] = form_response.first_error_message
      end

      render :new, locals: threatmetrix_view_variables
    end

    private

    def dob_ssn_params
      params.require(:doc_auth).permit(:ssn, dob: [:month, :day, :year])
    end

    def move_agent_proofed_user_pii_to_idv_session
      if agent_proofed_user
        session[:sp] = { issuer: agent_proofed_user&.issuer }
        idv_session.applicant = agent_proofed_user&.pii
        idv_session.agent_proofed = true
        # a successful agent proofed user should have phone precheck completed
        idv_session.mark_phone_step_started!
        idv_session.mark_phone_step_complete!
      else
        redirect_to idv_proofing_agent_expired_url
      end
    end

    def confirm_verification_needed
      redirect_to account_url unless verification_needed?
    end

    def verification_needed?
      IdentityConfig.store.idv_proofing_agent_enabled &&
        current_user.proofing_agent_user_awaiting_binding?
    end

    def tmx_job_attrs
      {
        user_id: current_user.id,
        applicant_pii: idv_session.applicant,
        request_ip: request&.ip,
        threatmetrix_session_id: idv_session.threatmetrix_session_id,
        timer: JobHelpers::Timer.new,
        current_sp:,
        workflow: :proofing_agent,
      }
    end
  end
end
