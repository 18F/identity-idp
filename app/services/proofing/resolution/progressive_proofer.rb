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

      attr_reader :plugins

      def initialize(**plugins)
        @plugins = {
          threatmetrix: Plugins::ThreatMetrixPlugin.new,
          residential_address: Plugins::InstantVerifyResidentialAddressPlugin.new,
          resolution: Plugins::InstantVerifyStateIdAddressPlugin.new,
          state_id: Plugins::AamvaPlugin.new,
          **plugins,
        }.freeze
      end

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
        applicant_pii = applicant_pii.except(:best_effort_phone_number_for_socure)

        device_profiling_result = plugins[:threatmetrix].call(
          applicant_pii:,
          current_sp:,
          threatmetrix_session_id:,
          request_ip:,
          timer:,
          user_email:,
        )

        instant_verify_residential_result = plugins[:residential_address].call(
          applicant_pii:,
          current_sp:,
          ipp_enrollment_in_progress:,
          timer:,
        )

        instant_verify_result = plugins[:resolution].call(
          applicant_pii:,
          current_sp:,
          instant_verify_residential_result:,
          ipp_enrollment_in_progress:,
          timer:,
        )

        state_id_result = plugins[:state_id].call(
          applicant_pii:,
          current_sp:,
          instant_verify_result:,
          ipp_enrollment_in_progress:,
          timer:,
        )

        ResultAdjudicator.new(
          device_profiling_result:,
          ipp_enrollment_in_progress:,
          resolution_result: instant_verify_result,
          should_proof_state_id: Plugins::AamvaPlugin.aamva_supports_state_id_jurisdiction?(
            applicant_pii,
          ),
          state_id_result:,
          residential_resolution_result: instant_verify_residential_result,
          same_address_as_id: applicant_pii[:same_address_as_id],
          applicant_pii:,
        )
      end
    end
  end
end
