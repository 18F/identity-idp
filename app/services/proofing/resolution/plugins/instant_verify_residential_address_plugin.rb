# frozen_string_literal: true

module Proofing
  module Resolution
    module Plugins
      class InstantVerifyResidentialAddressPlugin
        def call(
          applicant_pii:,
          current_sp:,
          ipp_enrollment_in_progress:,
          timer:
        )
          return residential_address_unnecessary_result unless ipp_enrollment_in_progress

          timer.time('residential address') do
            proofer.proof(applicant_pii)
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

        def residential_address_unnecessary_result
          Proofing::Resolution::Result.new(
            success: true, errors: {}, exception: nil, vendor_name: 'ResidentialAddressNotRequired',
          )
        end
      end
    end
  end
end
