# frozen_string_literal: true

module Idv
  class EnterDobSsnController < ApplicationController
    include Idv::AvailabilityConcern
    include IdvStepConcern
    include Idv::StepIndicatorConcern

    before_action :confirm_two_factor_authenticated
    before_action :move_agent_proofed_user_pii_to_idv_session, only: [:new]

    def new
      @dob_ssn_form = Idv::DobSsnForm.new(idv_session.applicant)
    end

    def create
      @dob_ssn_form = Idv::DobSsnForm.new(idv_session.applicant)

      form_response = @dob_ssn_form.submit(
        ssn: dob_ssn_params[:ssn],
        dob: parse_form_date,
      )

      if form_response.success?
        return redirect_to idv_enter_password_url if verify_dob_ssn_matches_applicant_pii?
      end

      render :new
    end

    private

    def dob_ssn_params
      params.require(:doc_auth).permit(:ssn, dob: [:month, :day, :year])
    end

    def parse_form_date
      MemorableDateComponent.extract_date_param(dob_ssn_params[:dob])
    end

    def move_agent_proofed_user_pii_to_idv_session
      agent_proofed_user = current_user.pending_agent_proofed_session&.load_agent_proofed_user
      if agent_proofed_user
        idv_session.applicant = agent_proofed_user&.pii
        idv_session.agent_proofed = true
      end
    end

    def verify_dob_ssn_matches_applicant_pii?
      ssn_match = idv_session.applicant[:ssn] == dob_ssn_params[:ssn]
      dob_match = idv_session.applicant[:dob] == parse_form_date

      idv_session.proofing_agent_match = ssn_match && dob_match
      idv_session.proofing_agent_match
    end
  end
end
