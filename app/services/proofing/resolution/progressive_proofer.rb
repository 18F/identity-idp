# frozen_string_literal: true

module Proofing
  module Resolution
    # Uses a combination of LexisNexis InstantVerify and AAMVA checks to verify that
    # a user's identity can be resolved against authoritative sources. This includes logic for when:
    #   1. The user is or is not within an AAMVA-participating jurisdiction
    #   2. The user has only provided one address for their residential and identity document
    #      address or separate residential and identity document addresses
    class ProgressiveProofer
      attr_reader :applicant_pii, :timer, :current_sp
      attr_reader :aamva_plugin, :threatmetrix_plugin

      def initialize
        @aamva_plugin = Plugins::AamvaPlugin.new
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
        @applicant_pii = applicant_pii.except(:best_effort_phone_number_for_socure)
        @timer = timer
        @ipp_enrollment_in_progress = ipp_enrollment_in_progress
        @current_sp = current_sp

        device_profiling_result = threatmetrix_plugin.call(
          applicant_pii:,
          current_sp:,
          threatmetrix_session_id:,
          request_ip:,
          timer:,
          user_email:,
        )

        @residential_instant_verify_result = proof_residential_address_if_needed
        @instant_verify_result = proof_id_address_with_lexis_nexis_if_needed

        state_id_result = aamva_plugin.call(
          applicant_pii:,
          current_sp:,
          instant_verify_result:,
          ipp_enrollment_in_progress:,
          timer:,
        )

        ResultAdjudicator.new(
          device_profiling_result: device_profiling_result,
          ipp_enrollment_in_progress: ipp_enrollment_in_progress,
          resolution_result: instant_verify_result,
          should_proof_state_id:
            Plugins::AamvaPlugin.aamva_supports_state_id_jurisdiction?(applicant_pii),
          state_id_result: state_id_result,
          residential_resolution_result: residential_instant_verify_result,
          same_address_as_id: applicant_pii[:same_address_as_id],
          applicant_pii: applicant_pii,
        )
      end

      private

      attr_reader :device_profiling_result,
                  :residential_instant_verify_result,
                  :instant_verify_result

      def proof_residential_address_if_needed
        return residential_address_unnecessary_result unless ipp_enrollment_in_progress?

        timer.time('residential address') do
          resolution_proofer.proof(applicant_pii_with_residential_address)
        end.tap do |result|
          add_sp_cost(:lexis_nexis_resolution, result.transaction_id)
        end
      end

      def residential_address_unnecessary_result
        Proofing::Resolution::Result.new(
          success: true, errors: {}, exception: nil, vendor_name: 'ResidentialAddressNotRequired',
        )
      end

      def resolution_cannot_pass
        Proofing::Resolution::Result.new(
          success: false, errors: {}, exception: nil, vendor_name: 'ResolutionCannotPass',
        )
      end

      def proof_id_address_with_lexis_nexis_if_needed
        if same_address_as_id? && ipp_enrollment_in_progress?
          return residential_instant_verify_result
        end
        return resolution_cannot_pass unless residential_instant_verify_result.success?

        timer.time('resolution') do
          resolution_proofer.proof(applicant_pii_with_state_id_address)
        end.tap do |result|
          add_sp_cost(:lexis_nexis_resolution, result.transaction_id)
        end
      end

      def same_address_as_id?
        applicant_pii[:same_address_as_id].to_s == 'true'
      end

      def ipp_enrollment_in_progress?
        @ipp_enrollment_in_progress
      end

      def resolution_proofer
        @resolution_proofer ||=
          if IdentityConfig.store.proofer_mock_fallback
            Proofing::Mock::ResolutionMockClient.new
          else
            Proofing::LexisNexis::InstantVerify::Proofer.new(
              instant_verify_workflow: IdentityConfig.store.lexisnexis_instant_verify_workflow,
              account_id: IdentityConfig.store.lexisnexis_account_id,
              base_url: IdentityConfig.store.lexisnexis_base_url,
              username: IdentityConfig.store.lexisnexis_username,
              password: IdentityConfig.store.lexisnexis_password,
              hmac_key_id: IdentityConfig.store.lexisnexis_hmac_key_id,
              hmac_secret_key: IdentityConfig.store.lexisnexis_hmac_secret_key,
              request_mode: IdentityConfig.store.lexisnexis_request_mode,
            )
          end
      end

      def applicant_pii_with_state_id_address
        if ipp_enrollment_in_progress?
          with_state_id_address(applicant_pii)
        else
          applicant_pii
        end
      end

      def applicant_pii_with_residential_address
        applicant_pii
      end

      def add_sp_cost(token, transaction_id)
        Db::SpCost::AddSpCost.call(current_sp, token, transaction_id: transaction_id)
      end

      # Make a copy of pii with the user's state ID address overwriting the address keys
      # Need to first remove the address keys to avoid key/value collision
      def with_state_id_address(pii)
        pii.except(*SECONDARY_ID_ADDRESS_MAP.values).
          transform_keys(SECONDARY_ID_ADDRESS_MAP)
      end

      SECONDARY_ID_ADDRESS_MAP = {
        identity_doc_address1: :address1,
        identity_doc_address2: :address2,
        identity_doc_city: :city,
        identity_doc_address_state: :state,
        identity_doc_zipcode: :zipcode,
      }.freeze
    end
  end
end
