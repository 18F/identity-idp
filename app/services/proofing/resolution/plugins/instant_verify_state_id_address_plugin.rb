# frozen_string_literal: true

module Proofing
  module Resolution
    module Plugins
      class InstantVerifyStateIdAddressPlugin
        SECONDARY_ID_ADDRESS_MAP = {
          identity_doc_address1: :address1,
          identity_doc_address2: :address2,
          identity_doc_city: :city,
          identity_doc_address_state: :state,
          identity_doc_zipcode: :zipcode,
        }.freeze

        def call(
          applicant_pii:,
          current_sp:,
          instant_verify_residential_address_result:,
          ipp_enrollment_in_progress:,
          timer:
        )
          if same_address_as_id?(applicant_pii) && ipp_enrollment_in_progress
            return instant_verify_residential_address_result
          end

          return resolution_cannot_pass unless instant_verify_residential_address_result.success?

          applicant_pii_with_state_id_address =
            if ipp_enrollment_in_progress
              with_state_id_address(applicant_pii)
            else
              applicant_pii
            end

          timer.time('resolution') do
            proofer.proof(applicant_pii_with_state_id_address)
          end.tap do |result|
            Db::SpCost::AddSpCost.call(
              current_sp,
              :lexis_nexis_resolution,
              transaction_id: result.transaction_id,
            )
          end
        end

        def proofer
          @proofer ||= begin
            # Historically, proofer_mock_fallback has controlled whether we
            # use mock implementations of the Resolution and Address proofers
            # (true = use mock, false = don't use mock).
            # We are transitioning to a place where we will have separate
            # configs for both. For the time being, we want to keep support for
            # proofer_mock_fallback here. This can be removed after this code
            # has been deployed and configs have been updated in all relevant
            # environments.

            old_config_says_mock = IdentityConfig.store.proofer_mock_fallback
            old_config_says_iv = !old_config_says_mock
            new_config_says_mock =
              IdentityConfig.store.idv_resolution_default_vendor == :mock
            new_config_says_iv =
              IdentityConfig.store.idv_resolution_default_vendor == :instant_verify

            proofer_type =
              if new_config_says_mock && old_config_says_iv
                # This will be the case immediately after deployment, when
                # environment configs have not been updated. We need to
                # fall back to the old config here.
                :instant_verify
              elsif new_config_says_iv
                :instant_verify
              else
                :mock
              end

            if proofer_type == :mock
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
        end

        def resolution_cannot_pass
          Proofing::Resolution::Result.new(
            success: false, errors: {}, exception: nil, vendor_name: 'ResolutionCannotPass',
          )
        end

        def same_address_as_id?(applicant_pii)
          applicant_pii[:same_address_as_id].to_s == 'true'
        end

        # Make a copy of pii with the user's state ID address overwriting the address keys
        # Need to first remove the address keys to avoid key/value collision
        def with_state_id_address(pii)
          pii.except(*SECONDARY_ID_ADDRESS_MAP.values).
            transform_keys(SECONDARY_ID_ADDRESS_MAP)
        end
      end
    end
  end
end
