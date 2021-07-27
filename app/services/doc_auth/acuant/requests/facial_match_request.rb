require 'identity_doc_auth/acuant/request'
require 'identity_doc_auth/acuant/responses/facial_match_response'

module IdentityDocAuth
  module Acuant
    module Requests
      class FacialMatchRequest < IdentityDocAuth::Acuant::Request
        attr_reader :selfie_image, :document_face_image

        def initialize(config:, selfie_image:, document_face_image:)
          super(config: config)
          @selfie_image = selfie_image
          @document_face_image = document_face_image
        end

        def headers
          super().merge 'Content-Type' => 'application/json'
        end

        def url
          URI.join(config.facial_match_url, path)
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
              'SubscriptionId': config.assure_id_subscription_id,
            },
          }.to_json
        end

        def handle_http_response(http_response)
          IdentityDocAuth::Acuant::Responses::FacialMatchResponse.new(http_response)
        end

        def method
          :post
        end

        def metric_name
          'acuant_doc_auth_facial_match'
        end
      end
    end
  end
end
