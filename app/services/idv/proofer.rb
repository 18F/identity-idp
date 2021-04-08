module Idv
  module Proofer
    class << self
      def mock_fallback_enabled?
        IdentityConfig.store.proofer_mock_fallback
      end

      def resolution_job_class
        if mock_fallback_enabled?
          require 'identity-idp-functions/proof_resolution_mock'
          IdentityIdpFunctions::ProofResolutionMock
        else
          require 'identity-idp-functions/proof_resolution'
          IdentityIdpFunctions::ProofResolution
        end
      end

      def address_job_class
        if mock_fallback_enabled?
          require 'identity-idp-functions/proof_address_mock'
          IdentityIdpFunctions::ProofAddressMock
        else
          require 'identity-idp-functions/proof_address'
          IdentityIdpFunctions::ProofAddress
        end
      end

      def document_job_class
        if mock_fallback_enabled?
          require 'identity-idp-functions/proof_document_mock'
          IdentityIdpFunctions::ProofDocumentMock
        else
          require 'identity-idp-functions/proof_document'
          IdentityIdpFunctions::ProofDocument
        end
      end
    end
  end
end
