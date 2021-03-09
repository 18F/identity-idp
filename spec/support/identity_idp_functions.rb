require 'identity-idp-functions'
require 'identity-idp-functions/proof_address_mock'
require 'identity-idp-functions/proof_document_mock'
require 'identity-idp-functions/proof_resolution_mock'

module IdentityIdpFunctions
  module LoggingHelper
    # prevent console noise in specs
    def default_logger_io
      '/dev/null'
    end
  end
end
