module Idv
  class ProoferValidator
    def self.validate_vendors!
      if mock_fallback_enabled?
        require 'identity-idp-functions/proof_address_mock'
        require 'identity-idp-functions/proof_resolution_mock'
        require 'identity-idp-functions/proof_document_mock'
      else
        require 'identity-idp-functions/proof_address'
        require 'identity-idp-functions/proof_resolution'
        require 'identity-idp-functions/proof_document'
      end
    end

    def self.mock_fallback_enabled?
      Identity::Hostdata.settings.proofer_mock_fallback == 'true'
    end
  end
end
