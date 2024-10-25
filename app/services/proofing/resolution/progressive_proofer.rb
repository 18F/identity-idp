# frozen_string_literal: true

module Proofing
  module Resolution
    # Uses a combination of LexisNexis InstantVerify and AAMVA checks to verify that
    # a user's identity can be resolved against authoritative sources. This includes logic for when:
    #   1. The user is or is not within an AAMVA-participating jurisdiction
    #   2. The user has only provided one address for their residential and identity document
    #      address or separate residential and identity document addresses
    class ProgressiveProofer
      attr_reader :applicant_pii,
                  :ipp_enrollment_in_progress,
                  :request_ip,
                  :threatmetrix_session_id,
                  :timer,
                  :user_email,
                  :current_sp

      # @param [Hash] applicant_pii keys are symbols and values are strings, confidential user info
      # @param [Boolean] ipp_enrollment_in_progress flag that indicates if user will have
      #   both state id address and current residential address verified
      # @param [String] request_ip IP address for request
      # @param [String] threatmetrix_session_id identifies the threatmetrix session
      # @param [JobHelpers::Timer] timer indicates time elapsed to obtain results
      # @param [String] user_email email address for applicant
      # @return [ResultAdjudicator] object which contains the logic to determine proofing's result
      def proof(
        applicant_pii:,
        request_ip:,
        threatmetrix_session_id:,
        timer:,
        user_email:,
        ipp_enrollment_in_progress:,
        current_sp:
      )
        @applicant_pii = applicant_pii.except(:best_effort_phone_number_for_socure)
        @request_ip = request_ip
        @threatmetrix_session_id = threatmetrix_session_id
        @timer = timer
        @user_email = user_email
        @ipp_enrollment_in_progress = ipp_enrollment_in_progress
        @current_sp = current_sp

        @device_profiling_result = proof_with_threatmetrix_if_needed
        @residential_instant_verify_result = proof_residential_address_if_needed
        @instant_verify_result = proof_id_address_with_lexis_nexis_if_needed
        @state_id_result = proof_id_with_aamva_if_needed

        ResultAdjudicator.new(
          device_profiling_result: device_profiling_result,
          ipp_enrollment_in_progress: ipp_enrollment_in_progress,
          resolution_result: instant_verify_result,
          should_proof_state_id: Plugins::AamvaPlugin.aamva_supports_state_id_jurisdiction?(
            applicant_pii,
          ),
          state_id_result: state_id_result,
          residential_resolution_result: residential_instant_verify_result,
          same_address_as_id: applicant_pii[:same_address_as_id],
          applicant_pii: applicant_pii,
        )
      end

      private

      attr_reader :device_profiling_result,
                  :residential_instant_verify_result,
                  :instant_verify_result,
                  :state_id_result

      def proof_with_threatmetrix_if_needed
        Plugins::ThreatMetrixPlugin.new.call(
          applicant_pii:,
          current_sp:,
          threatmetrix_session_id:,
          request_ip:,
          timer:,
          user_email:,
        )
      end

      def proof_residential_address_if_needed
        Plugins::InstantVerifyResidentialAddressPlugin.new.call(
          applicant_pii:,
          current_sp:,
          ipp_enrollment_in_progress:,
          residential_instant_verify_result:,
          timer:,
        )
      end

      def proof_id_address_with_lexis_nexis_if_needed
        Plugins::InstantVerifyStateIdPlugin.new.call(
          applicant_pii:,
          current_sp:,
          ipp_enrollment_in_progress:,
          residential_instant_verify_result:,
          timer:,
        )
      end

      def proof_id_with_aamva_if_needed
        Plugins::AamvaPlugin.new.call(
          applicant_pii:,
          current_sp:,
          instant_verify_result:,
          ipp_enrollment_in_progress:,
          residential_instant_verify_result:,
          timer:,
        )
      end
    end
  end
end
