module Idv
  module Resolution
    class AamvaPlugin
      def resolve_identity(
        input:,
        next_plugin:,
        **
      )

        if input.state_id.nil?
          return next_plugin.call(
            aamva: {
              success: false,
              reason: :no_state_id,
            },
          )
        end

        if unsupported_jurisdiction?(input)
          return next_plugin.call(
            aamva: {
              success: false,
              reason: :unsupported_jurisdiction,
            },
          )
        end
      end

      def unsupported_jurisdiction?(input)
        !IdentityConfig.store.aamva_supported_jurisdictions.include?(
          input.state_id&.issuing_jurisdiction,
        )
      end

      private

      def proofer
        @proofer ||=
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
    end
  end
end
