module Idv
  module Proofer
    class << self
      def mock_fallback_enabled?
        AppConfig.env.proofer_mock_fallback == 'true'
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

      def document_job_class
        if mock_fallback_enabled?
          IdentityIdpFunctions::ProofDocumentMock
        else
          IdentityIdpFunctions::ProofDocument
        end
      end
    end
  end
end
