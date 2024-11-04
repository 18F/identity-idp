# frozen_string_literal: true

module Proofing
  module Resolution
    # Uses a combination of LexisNexis InstantVerify and AAMVA checks to verify that
    # a user's identity can be resolved against authoritative sources. This includes logic for when:
    #   1. The user is or is not within an AAMVA-participating jurisdiction
    #   2. The user has only provided one address for their residential and identity document
    #      address or separate residential and identity document addresses
    class ProgressiveProofer
      attr_reader :aamva_plugin,
                  :instant_verify_residential_address_plugin,
                  :instant_verify_state_id_address_plugin,
                  :threatmetrix_plugin

      def initialize
        @aamva_plugin = Plugins::AamvaPlugin.new
        @instant_verify_residential_address_plugin =
          Plugins::InstantVerifyResidentialAddressPlugin.new
        @instant_verify_state_id_address_plugin =
          Plugins::InstantVerifyStateIdAddressPlugin.new
        @threatmetrix_plugin = Plugins::ThreatMetrixPlugin.new
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

        device_profiling_result = threatmetrix_plugin.call(
          applicant_pii:,
          current_sp:,
          threatmetrix_session_id:,
          request_ip:,
          timer:,
          user_email:,
        )

        residential_address_resolution_result = instant_verify_residential_address_plugin.call(
          applicant_pii:,
          current_sp:,
          ipp_enrollment_in_progress:,
          timer:,
        )

        state_id_address_resolution_result = instant_verify_state_id_address_plugin.call(
          applicant_pii:,
          current_sp:,
          residential_address_resolution_result:,
          ipp_enrollment_in_progress:,
          timer:,
        )

        state_id_result = aamva_plugin.call(
          applicant_pii:,
          current_sp:,
          state_id_address_resolution_result:,
          ipp_enrollment_in_progress:,
          timer:,
        )

        ResultAdjudicator.new(
          device_profiling_result: device_profiling_result,
          ipp_enrollment_in_progress: ipp_enrollment_in_progress,
          resolution_result: state_id_address_resolution_result,
          should_proof_state_id: aamva_plugin.aamva_supports_state_id_jurisdiction?(applicant_pii),
          state_id_result: state_id_result,
          residential_resolution_result: residential_address_resolution_result,
          same_address_as_id: applicant_pii[:same_address_as_id],
          applicant_pii: applicant_pii,
        )
      end
    end
  end
end
