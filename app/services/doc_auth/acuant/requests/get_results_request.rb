module DocAuth
  module Acuant
    module Requests
      class GetResultsRequest < DocAuth::Acuant::Request
        attr_reader :instance_id

        def initialize(instance_id:)
          @instance_id = instance_id
        end

        def path
          "/AssureIDService/Document/#{instance_id}"
        end

        def headers
          super().merge 'Content-Type' => 'application/json'
        end

        def handle_http_response(http_response)
          DocAuth::Acuant::Responses::GetResultsResponse.new(http_response)
        end

        def method
          :get
        end
      end
    end
  end
end
