module DocAuth
  module LexisNexis
    module Requests
      class TrueIdRequest < DocAuth::LexisNexis::Request
        attr_reader :front_image, :back_image,  :selfie_image

        def initialize(front_image:, back_image:, selfie_image: nil)
          @front_image = front_image
          @back_image = back_image
          @selfie_image = selfie_image
        end

        def headers
          super().merge 'Content-Type' => 'application/json'
        end

        def path
          "/restws/identity/v2/#{account_id}/#{workflow}/conversation"
        end

        def body
          document = {
            Document: {
              Front: encode(front_image),
              Back: encode(back_image),
              DocumentType: 'DriversLicense',
            },
          }
          document[:Document][:Selfie] = encode(selfie_image) if selfie_image
          settings.merge(document).to_json
        end

        def handle_http_response(http_response)
          DocAuth::Response.new(success: http_response.status == 200)
        end

        def method
          :post
        end

        private

        def encode(image)
          Base64.strict_encode64(image)
        end
      end
    end
  end
end
