module Scripts
  module InheritedProofing
    module Va
      module LexisNexis
        module PhoneFinder
          class << self
            def call(user_pii)
              proofer = if IdentityConfig.store.proofer_mock_fallback
                Proofing::Mock::AddressMockClient.new
              else
                Proofing::LexisNexis::PhoneFinder::Proofer.new(
                  phone_finder_workflow: IdentityConfig.store.lexisnexis_phone_finder_workflow,
                  account_id: IdentityConfig.store.lexisnexis_account_id,
                  base_url: IdentityConfig.store.lexisnexis_base_url,
                  username: IdentityConfig.store.lexisnexis_username,
                  password: IdentityConfig.store.lexisnexis_password,
                  request_mode: IdentityConfig.store.lexisnexis_request_mode,
                )
              end

              proofer.proof user_pii
            end
          end
        end
      end
    end
  end
end
