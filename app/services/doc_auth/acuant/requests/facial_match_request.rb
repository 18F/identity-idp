module DocAuth
  module Acuant
    module Requests
      class FacialMatchRequest < DocAuth::Acuant::Request
        attr_reader :selfie_image, :document_face_image

        def initialize(selfie_image:, document_face_image:)
          @selfie_image = selfie_image
          @document_face_image = document_face_image
        end

        def headers
          super().merge 'Content-Type' => 'application/json'
        end

        def url
          URI.join(Figaro.env.acuant_facial_match_url, path)
        end

        def path
          '/api/v1/facematch'
        end

        def body
          {
            'Data': {
              'ImageOne': Base64.strict_encode64(selfie_image),
              'ImageTwo': Base64.strict_encode64(document_face_image),
            },
            'Settings': {
              'SubscriptionId': Figaro.env.acuant_assure_id_subscription_id,
            },
          }.to_json
        end

        def handle_http_response(http_response)
          DocAuth::Acuant::Responses::FacialMatchResponse.new(http_response)
        end

        def method
          :post
        end
      end
    end
  end
end
