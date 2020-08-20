module DocAuth
  module Acuant
    module Responses
      class GetFaceImageResponse < DocAuth::Response
        attr_reader :http_response

        def initialize(http_response)
          @http_response = http_response
          super(success: true)
        end

        def image
          http_response.body
        end
      end
    end
  end
end
