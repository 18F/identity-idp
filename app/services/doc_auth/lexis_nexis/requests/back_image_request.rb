module DocAuth
  module LexisNexis
    module Requests
      class BackImageRequest < DocAuth::LexisNexis::Request
        attr_reader :back_image

        def initialize(back_image:)
          @back_image = back_image
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
              Back: Base64.strict_encode64(back_image),
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
