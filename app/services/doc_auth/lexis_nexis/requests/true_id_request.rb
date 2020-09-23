module DocAuth
  module LexisNexis
    module Requests
      class TrueIdRequest < DocAuth::LexisNexis::Request
        attr_reader :front_image, :back_image, :selfie_image, :liveness_checking_enabled

        def initialize(
          front_image:,
          back_image:,
          selfie_image: nil,
          liveness_checking_enabled: nil
        )
          @front_image = front_image
          @back_image = back_image
          @selfie_image = selfie_image
          @liveness_checking_enabled = liveness_checking_enabled
        end

        private

        def body
          document = {
            Document: {
              Front: encode(front_image),
              Back: encode(back_image),
              DocumentType: 'DriversLicense',
            },
          }

          document[:Document][:Selfie] = encode(selfie_image) if liveness_checking_enabled

          settings.merge(document).to_json
        end

        def handle_http_response(http_response)
          LexisNexis::Responses::TrueIdResponse.new(http_response, liveness_checking_enabled)
        end

        def method
          :post
        end

        def account_id
          Figaro.env.lexisnexis_trueid_account_id
        end

        def username
          Figaro.env.lexisnexis_trueid_username
        end

        def password
          Figaro.env.lexisnexis_trueid_password
        end

        def workflow
          if liveness_checking_enabled
            Figaro.env.lexisnexis_trueid_liveness_workflow
          else
            Figaro.env.lexisnexis_trueid_noliveness_workflow
          end
        end

        def encode(image)
          Base64.strict_encode64(image)
        end
      end
    end
  end
end
