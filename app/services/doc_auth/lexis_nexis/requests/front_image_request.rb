module DocAuth
  module LexisNexis
    module Requests
      class FrontImageRequest < DocAuth::LexisNexis::Request
        attr_reader :front_image

        def initialize(front_image:)
          @front_image = front_image
        end

        def headers
          super().merge 'Content-Type' => 'application/json'
        end

        def path
          "/restws/identity/v2/#{account_id}/#{workflow}/conversation"
        end

        def body
          settings.merge({
            Document: {
              Front: Base64.strict_encode64(front_image),
              DocumentType: 'DriversLicense',
            },
          }).to_json
        end

        def handle_http_response(http_response)
          byebug
          DocAuth::Response.new(success: true)
        end

        def method
          :post
        end
      end
    end
  end
end
