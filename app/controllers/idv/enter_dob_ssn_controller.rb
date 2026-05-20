# frozen_string_literal: true

module Idv
  class EnterDobSsnController < ApplicationController
    include Idv::AvailabilityConcern
    include IdvStepConcern
    include Idv::StepIndicatorConcern

    before_action :confirm_two_factor_authenticated
    before_action :move_agent_proofed_user_pii_to_idv_session, only: [:new]

    def new
      # move_agent_proofed_user_pii_to_idv_session

      @dob_ssn_form = Idv::DobSsnForm.new(idv_session.applicant)
    end

    def create
      @dob_ssn_form = Idv::DobSsnForm.new(idv_session.applicant)

      form_response = @dob_ssn_form.submit(
        ssn: dob_ssn_params[:ssn],
        dob: MemorableDateComponent.extract_date_param(dob_ssn_params[:dob]),
      )

      print "FORM RESPONSE: #{form_response.inspect}"

      if form_response.success?
        print "DOB SSN MATCHES #{verify_dob_ssn_matches_applicant_pii?}"
        print idv_session.applicant.inspect
        return redirect_to idv_enter_password_url if verify_dob_ssn_matches_applicant_pii?

        render :new
      else
        render :new
      end
    end

    private

    def dob_ssn_params
      params.require(:doc_auth).permit(:ssn, dob: [:month, :day, :year])
    end

    def move_agent_proofed_user_pii_to_idv_session
      agent_proofed_user = current_user.pending_agent_proofed_session&.load_agent_proofed_user
      idv_session.applicant = agent_proofed_user&.pii
      idv_session.agent_proofed = true
    end

    def verify_dob_ssn_matches_applicant_pii?
      ssn_match = idv_session.applicant[:ssn] == dob_ssn_params[:ssn]
      dob_match = idv_session.applicant[:dob] == MemorableDateComponent.extract_date_param(dob_ssn_params[:dob])

      print "SSN #{dob_ssn_params[:ssn]}, APPLICANT SSN: #{idv_session.applicant[:ssn]}"

      print "SSN MATCH: #{ssn_match}, DOB MATCH: #{dob_match}"

      idv_session.proofing_agent_match = ssn_match && dob_match
      idv_session.proofing_agent_match
    end
  end
end
