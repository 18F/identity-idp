# frozen_string_literal: true

module Proofing
  module Aamva
    class ProoferFactory
      attr_accessor :resolution_context

      # @param [Proofing::Resolution::ResolutionContext] resolution_context
      def initialize(resolution_context)
        @resolution_context = resolution_context
      end

      def get_proofer
        app_config_store = resolution_context.app_config_store()
        user_email = resolution_context.user_email()
        if Pii::Classifier.user_for_test_request_logging?(user_email) &&
           !app_config_store.proofer_mock_fallback
          logging_state_id_proofer
        elsif app_config_store.proofer_mock_fallback
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

      private

      # @param [String] address_type: either 'id_address' or 'residential_address'
      def logging_state_id_proofer
        Proofing::Aamva::LoggingProofer.new(
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
  end
end
