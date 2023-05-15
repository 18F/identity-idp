module Proofing
  module LexisNexis
    module InstantVerify
      class ProoferFactory
        ## Factory class to create a proofer based on resolution context

        attr_accessor :resolution_context

        # @param [Proofing::Resolution::ResolutionContext] resolution_context
        def initialize(resolution_context)
          @resolution_context = resolution_context
        end

        def get_proofer(address_type:)
          app_config_store = resolution_context.app_config_store
          user_email = resolution_context.user_email
          if Pii::Classifier.user_for_test_request_logging?(user_email) &&
             !app_config_store.proofer_mock_fallback
            logging_resolution_proofer(address_type: address_type)
          elsif app_config_store.proofer_mock_fallback
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

        private

        # @param [String] address_type: either 'id_address' or 'residential_address'
        def logging_resolution_proofer(address_type:)
          Proofing::LexisNexis::InstantVerify::LoggingProofer.new(
            {
              instant_verify_workflow: IdentityConfig.store.lexisnexis_instant_verify_workflow,
              account_id: IdentityConfig.store.lexisnexis_account_id,
              base_url: IdentityConfig.store.lexisnexis_base_url,
              username: IdentityConfig.store.lexisnexis_username,
              password: IdentityConfig.store.lexisnexis_password,
              hmac_key_id: IdentityConfig.store.lexisnexis_hmac_key_id,
              hmac_secret_key: IdentityConfig.store.lexisnexis_hmac_secret_key,
              request_mode: IdentityConfig.store.lexisnexis_request_mode,
            },
            address_type: address_type,
          )
        end
      end
    end
  end
end
