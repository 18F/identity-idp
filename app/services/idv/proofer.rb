module Idv
  module Proofer
    @vendors = nil

    class << self
      def validate_vendors!
        if mock_fallback_enabled?
          require 'identity-idp-functions/proof_address_mock'
          require 'identity-idp-functions/proof_resolution_mock'
        else
          require 'identity-idp-functions/proof_address'
          require 'identity-idp-functions/proof_resolution'
        end
      end

      def resolution_job_class
        if mock_fallback_enabled?
          IdentityIdpFunctions::ProofResolutionMock
        else
          IdentityIdpFunctions::ProofResolution
        end
      end

      def address_job_class
        if mock_fallback_enabled?
          IdentityIdpFunctions::ProofAddressMock
        else
          IdentityIdpFunctions::ProofAddress
        end
      end

      def mock_fallback_enabled?
        Figaro.env.proofer_mock_fallback == 'true'
      end
    end
  end
end
