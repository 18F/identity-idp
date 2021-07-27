require 'identity_doc_auth/acuant/request'
require 'identity_doc_auth/acuant/responses/get_results_response'

module IdentityDocAuth
  module Acuant
    module Requests
      class GetResultsRequest < IdentityDocAuth::Acuant::Request
        attr_reader :instance_id

        def initialize(config:, instance_id:)
          super(config: config)
          @instance_id = instance_id
        end

        def path
          "/AssureIDService/Document/#{instance_id}"
        end

        def headers
          super().merge 'Content-Type' => 'application/json'
        end

        def handle_http_response(http_response)
          IdentityDocAuth::Acuant::Responses::GetResultsResponse.new(http_response, config)
        end

        def method
          :get
        end

        def metric_name
          'acuant_doc_auth_get_results'
        end
      end
    end
  end
end
