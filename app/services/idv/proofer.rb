module Idv
  module Proofer
    @vendors = nil

    class << self
      def resolution_job_class
        if Idv::ProoferValidator.mock_fallback_enabled?
          IdentityIdpFunctions::ProofResolutionMock
        else
          IdentityIdpFunctions::ProofResolution
        end
      end

      def address_job_class
        if Idv::ProoferValidator.mock_fallback_enabled?
          IdentityIdpFunctions::ProofAddressMock
        else
          IdentityIdpFunctions::ProofAddress
        end
      end
    end
  end
end
