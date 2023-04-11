module Proofing
  module Resolution
    # Uses a combination of LexisNexis InstantVerify and AAMVA checks to verify that
    # a user's identity can be resolved against authoritative sources. This includes logic for when:
    #   1. The user is or is not within an AAMVA-participating jurisdiction
    #   2. The user has only provided one address for their residential and identity document
    #      address or separate residential and identity document addresses
    class ProgressiveProofer
      def initialize(should_proof_state_id:, double_address_verification:)
        @should_proof_state_id = should_proof_state_id
        @double_address_verification = double_address_verification
      end

      def proof(applicant_pii:, timer:)
        resolution_result = proof_resolution(
          applicant_pii: applicant_pii,
          timer: timer,
        )
        state_id_result = proof_state_id(
          applicant_pii: applicant_pii,
          timer: timer,
          resolution_result: resolution_result,
        )

        ResultAdjudicator.new(
          resolution_result: resolution_result,
          should_proof_state_id: should_proof_state_id,
          state_id_result: state_id_result,
        )
      end

      private

      attr_reader :should_proof_state_id, :double_address_verification

      def proof_resolution(applicant_pii:, timer:)
        resolution_result = nil
        timer.time('resolution') do
          resolution_result = resolution_proofer.proof(pii_with_state_id_address(applicant_pii))
        end

        resolution_result
      end

      def proof_state_id(applicant_pii:, timer:,
                         resolution_result:)
        state_id_result = Proofing::StateIdResult.new(
          success: true, errors: {}, exception: nil, vendor_name: 'UnsupportedJurisdiction',
        )

        if should_proof_state_id &&
           user_can_pass_after_state_id_check?(resolution_result)
          timer.time('state_id') do
            state_id_result = state_id_proofer.proof(pii_with_state_id_address(applicant_pii))
          end
        end

        state_id_result
      end

      def user_can_pass_after_state_id_check?(resolution_result)
        return true if resolution_result.success?
        # For failed IV results, this method validates that the user is eligible to pass if the
        # failed attributes are covered by the same attributes in a successful AAMVA response
        # aka the Get-to-Yes w/ AAMVA feature.
        return false unless resolution_result.failed_result_can_pass_with_additional_verification?

        attributes_aamva_can_pass = [:address, :dob, :state_id_number]
        results_that_cannot_pass_aamva =
          resolution_result.attributes_requiring_additional_verification - attributes_aamva_can_pass

        results_that_cannot_pass_aamva.blank?
      end

      def pii_with_state_id_address(applicant_pii)
        return with_state_id_address(applicant_pii) if double_address_verification

        applicant_pii
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
              request_mode: IdentityConfig.store.lexisnexis_request_mode,
            )
          end
      end

      def state_id_proofer
        @state_id_proofer ||=
          if IdentityConfig.store.proofer_mock_fallback
            Proofing::Mock::StateIdMockClient.new
          else
            Proofing::Aamva::Proofer.new(
              auth_request_timeout: IdentityConfig.store.aamva_auth_request_timeout,
              auth_url: IdentityConfig.store.aamva_auth_url,
              cert_enabled: IdentityConfig.store.aamva_cert_enabled,
              private_key: IdentityConfig.store.aamva_private_key,
              public_key: IdentityConfig.store.aamva_public_key,
              verification_request_timeout: IdentityConfig.store.aamva_verification_request_timeout,
              verification_url: IdentityConfig.store.aamva_verification_url,
            )
          end
      end

      # Make a copy of pii with the user's state ID address overwriting the address keys
      def with_state_id_address(pii)
        pii.transform_keys(SECONDARY_ID_ADDRESS_MAP)
      end

      SECONDARY_ID_ADDRESS_MAP = {
        state_id_address1: :address1,
        state_id_address2: :address2,
        state_id_city: :city,
        state_id_state: :state,
        state_id_zipcode: :zipcode,
      }.freeze
    end
  end
end
