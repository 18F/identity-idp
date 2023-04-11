module Proofing
  module Resolution
    class Proofer
      def initialize(should_proof_state_id:, capture_secondary_id_enabled:)
        @should_proof_state_id = should_proof_state_id
        @capture_secondary_id_enabled = capture_secondary_id_enabled
      end

      def proof(applicant_pii:, timer:)
        residential_address_result = proof_residential_address(
          applicant_pii: applicant_pii,
          timer: timer,
        )
        state_id_address_result = proof_state_id_address(
          applicant_pii: applicant_pii,
          timer: timer,
          residential_address_result: residential_address_result,
        )
        state_id_result = proof_state_id(
          applicant_pii: applicant_pii,
          timer: timer,
          residential_address_result: residential_address_result,
          state_id_address_result: state_id_address_result,
        )

        ResultAdjudicator.new(
          capture_secondary_id_enabled: capture_secondary_id_enabled,
          residential_address_result: residential_address_result,
          resolution_result: state_id_address_result,
          should_proof_state_id: should_proof_state_id,
          state_id_result: state_id_result,
        )
      end

      private

      attr_reader :should_proof_state_id, :capture_secondary_id_enabled

      def proof_residential_address(applicant_pii:, timer:)
        residential_address_result = Proofing::AddressResult.new(
          success: true, errors: {}, exception: nil, vendor_name: 'ResidentialAddressNotRequired',
        )

        if capture_secondary_id_enabled
          timer.time('residential address') do
            residential_address_result = resolution_proofer.proofer(applicant_pii)
          end
        end

        residential_address_result
      end

      def proof_state_id_address(applicant_pii:, timer:, residential_address_result:)
        state_id_address_result = Proofing::AddressResult.new(
          success: true, errors: {}, exception: nil, vendor_name: 'ResidentialAddressFailed',
        )

        if residential_address_can_pass_after_state_id_check?(residential_address_result)
          state_id_address_result = timer.time('resolution') do
            resolution_proofer.proof(pii_with_state_id_address(applicant_pii))
          end
        end

        state_id_address_result
      end

      def proof_state_id(applicant_pii:, timer:, residential_address_result:,
                         state_id_address_result:)
        state_id_result = Proofing::StateIdResult.new(
          success: true, errors: {}, exception: nil, vendor_name: 'UnsupportedJurisdiction',
        )

        if should_proof_state_id &&
           residential_address_can_pass_after_state_id_check?(residential_address_result) &&
           state_id_address_can_pass_after_state_id_check?(state_id_address_result)
          timer.time('state_id') do
            state_id_result = state_id_proofer.proof(pii_with_state_id_address(applicant_pii))
          end
        end

        state_id_result
      end

      def pii_with_state_id_address(applicant_pii)
        with_state_id_address(applicant_pii) if capture_secondary_id_enabled

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
        pii_with_state_id_address = pii.transform_keys(SECONDARY_ID_ADDRESS_MAP)
        # todo (LG-9237): Remove the below lines once the user's state ID address state
        # is saved as :state_id_state
        pii_with_state_id_address[:state_id_jurisdiction] = pii[:state_id_jurisdiction]
        pii_with_state_id_address
      end

      SECONDARY_ID_ADDRESS_MAP = {
        state_id_address1: :address1,
        state_id_address2: :address2,
        state_id_city: :city,
        # todo (LG-9237): Change below to `state_id_state: :state` once we are collecting
        # user's state ID address state as :state_id_state
        state_id_jurisdiction: :state,
        state_id_zipcode: :zipcode,
      }.freeze
    end
  end
end
