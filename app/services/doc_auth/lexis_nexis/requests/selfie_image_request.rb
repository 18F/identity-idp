module DocAuth
  module LexisNexis
    module Requests
      class SelfieImageRequest < DocAuth::LexisNexis::Request
        attr_reader :selfie_image

        def initialize(selfie_image:)
          @selfie_image = selfie_image
        end

        def headers
          super().merge 'Content-Type' => 'application/json'
        end

        def url
          URI.join(Figaro.env.lexisnexis_base_url, path)
        end

        def path
          "/restws/identity/v2/#{account_id}/#{workflow}/conversation"
        end

        def body
          settings.merge({
            Document: {
              Selfie: Base64.strict_encode64(selfie_image),
              DocumentType: 'DriversLicense',
            },
          }).to_json
        end

        def handle_http_response(http_response)
          DocAuth::LexisNexis::Responses::FacialMatchResponse.new(http_response)
        end

        def method
          :post
        end
      end
    end
  end
end
