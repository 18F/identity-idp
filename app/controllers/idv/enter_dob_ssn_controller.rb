# frozen_string_literal: true

module Idv
  class EnterDobSsnController < ApplicationController
    include Idv::AvailabilityConcern
    include IdvStepConcern
    include Idv::StepIndicatorConcern
    include Idv::ProofingAgentConcern

    before_action :confirm_two_factor_authenticated
    before_action :confirm_verification_needed
    before_action :move_agent_proofed_user_pii_to_idv_session

    def new
      @dob_ssn_form = Idv::DobSsnForm.new(idv_session.applicant)
      analytics.idv_proofing_agent_user_confirmation_visited(**proofing_agent_analytics)
    end

    def create
      @dob_ssn_form = Idv::DobSsnForm.new(idv_session.applicant)

      form_response = @dob_ssn_form.submit(
        ssn: normalized_ssn,
        dob: parse_form_date,
      )

      analytics.idv_proofing_agent_user_confirmation_submitted(
        **proofing_agent_analytics,
        success: form_response.success?,
        dob_match: dob_match?,
        ssn_match: ssn_match?,
        dob_and_ssn_match: verify_dob_ssn_matches_applicant_pii?,
      )

      if form_response.success?
        return redirect_to idv_enter_password_url if verify_dob_ssn_matches_applicant_pii?
        flash.now[:error] = t('idv.failure.dob_ssn.warning')
      else
        flash.now[:error] = form_response.first_error_message
      end

      render :new
    end

    private

    def dob_ssn_params
      params.require(:doc_auth).permit(:ssn, dob: [:month, :day, :year])
    end

    def normalized_ssn
      SsnFormatter.normalize(dob_ssn_params[:ssn])
    end

    def parse_form_date
      MemorableDateComponent.extract_date_param(dob_ssn_params[:dob])
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

    def dob_match?
      idv_session.applicant[:dob] == parse_form_date
    end

    def ssn_match?
      idv_session.applicant[:ssn] == normalized_ssn
    end

    def verify_dob_ssn_matches_applicant_pii?
      idv_session.proofing_agent_match = ssn_match? && dob_match?
      idv_session.proofing_agent_match
    end

    def confirm_verification_needed
      return if current_user.proofing_agent_pending?
      redirect_to account_url
    end
  end
end
