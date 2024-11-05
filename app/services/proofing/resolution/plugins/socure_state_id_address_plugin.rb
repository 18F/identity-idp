# frozen_string_literal: true

module Proofing
  module Resolution
    module Plugins
      class SocureStateIdAddressPlugin
        include StateIdAddressPlugin

        def sp_cost_token
          :socure_resolution
        end

        def proofer
          @proofer ||=
            if IdentityConfig.store.proofer_mock_fallback
              Proofing::Mock::ResolutionMockClient.new
            else
              Proofing::Socure::IdPlus::Proofer.new(
                Proofing::Socure::IdPlus::Config.new(
                  api_key: IdentityConfig.store.socure_idplus_api_key,
                  base_url: IdentityConfig.store.socure_idplus_base_url,
                  timeout: IdentityConfig.store.socure_idplus_timeout_in_seconds,
                ),
              )
            end
        end
      end
    end
  end
end
