require 'json'
require 'identity_doc_auth/response'

module IdentityDocAuth
  module Acuant
    module Responses
      class CreateDocumentResponse < IdentityDocAuth::Response
        attr_reader :instance_id

        def initialize(http_response)
          @instance_id = JSON.parse(http_response.body)
          super(success: true)
        end
      end
    end
  end
end
