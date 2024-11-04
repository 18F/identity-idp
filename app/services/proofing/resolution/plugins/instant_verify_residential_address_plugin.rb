# frozen_string_literal: true

module Proofing
  module Resolution
    module Plugins
      class InstantVerifyResidentialAddressPlugin
        include ResidentialAddressPlugin

        def proofer
          @proofer ||=
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

        def sp_cost_token
          :lexis_nexis_resolution
        end
      end
    end
  end
end
