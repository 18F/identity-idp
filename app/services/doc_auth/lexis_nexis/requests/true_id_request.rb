require 'identity_doc_auth/lexis_nexis/request'

module IdentityDocAuth
  module LexisNexis
    module Requests
      class TrueIdRequest < IdentityDocAuth::LexisNexis::Request
        attr_reader :front_image, :back_image, :selfie_image, :liveness_checking_enabled

        def initialize(
          config:,
          front_image:,
          back_image:,
          selfie_image: nil,
          liveness_checking_enabled: nil
        )
          super(config: config)
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
          LexisNexis::Responses::TrueIdResponse.new(http_response, liveness_checking_enabled, config)
        end

        def method
          :post
        end

        def account_id
          config.trueid_account_id
        end

        def username
          config.trueid_username
        end

        def password
          config.trueid_password
        end

        def workflow
          if liveness_checking_enabled
            config.trueid_liveness_workflow
          else
            config.trueid_noliveness_workflow
          end
        end

        def encode(image)
          Base64.strict_encode64(image)
        end

        def metric_name
          'lexis_nexis_doc_auth_true_id'
        end
      end
    end
  end
end
