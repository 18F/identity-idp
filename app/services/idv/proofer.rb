module Idv
  module Proofer
    @vendors = nil

    class << self
      def validate_vendors!
        if mock_fallback_enabled?
          require 'identity-idp-functions/proof_address_mock'
        else
          require 'identity-idp-functions/proof_address'
        end

        resolution_vendor.new
        state_id_vendor.new
      end

      def resolution_vendor
        if mock_fallback_enabled?
          ResolutionMock
        else
          LexisNexis::InstantVerify::Proofer
        end
      end

      def state_id_vendor
        if mock_fallback_enabled?
          StateIdMock
        else
          Aamva::Proofer
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
