# frozen_string_literal: true

module DocAuth
  module LexisNexis
    module Requests
      class TrueIdRequest < DocAuth::LexisNexis::Request
        attr_reader :front_image, :back_image, :passport_image, :selfie_image,
                    :liveness_checking_required, :document_type_requested, :passport_requested

        def initialize(
          config:,
          user_uuid:,
          uuid_prefix:,
          document_type_requested:,
          front_image: nil,
          back_image: nil,
          passport_image: nil,
          selfie_image: nil,
          image_source: nil,
          images_cropped: false,
          liveness_checking_required: false,
          passport_requested: false
        )
          super(config: config, user_uuid: user_uuid, uuid_prefix: uuid_prefix)
          @front_image = front_image
          @back_image = back_image
          @passport_image = passport_image
          @selfie_image = selfie_image
          @image_source = image_source
          @images_cropped = images_cropped
          # when set to required, be sure to pass in selfie_imaged
          @liveness_checking_required = liveness_checking_required
          @document_type_requested = document_type_requested
          @passport_requested = passport_requested
        end

        def request_context
          {
            workflow: workflow,
            document_type_requested: document_type_requested,
          }
        end

        private

        def body
          document = {
            Document: {
              Front: encode(id_front_image),
              Back: (encode(back_image) if back_image_required?),
              Selfie: (encode(selfie_image) if liveness_checking_required),
              DocumentType: document_type_requested,
              ImageCroppingMode: image_cropping_mode,
            }.compact,
          }

          settings.merge(document).to_json
        end

        def id_front_image
          # TrueID front_image required whether driver's license or passport
          case document_type_requested
          when DocumentTypes::PASSPORT
            passport_image
          else
            front_image
          end
        end

        def handle_http_response(http_response)
          LexisNexis::Responses::TrueIdResponse.new(
            http_response:,
            passport_requested:,
            config:,
            liveness_checking_enabled: liveness_checking_required,
            request_context:,
          )
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
          if @images_cropped
            liveness_checking_required ?
              config.trueid_liveness_nocropping_workflow :
              config.trueid_noliveness_nocropping_workflow
          else
            liveness_checking_required ?
              config.trueid_liveness_cropping_workflow :
              config.trueid_noliveness_cropping_workflow
          end
        end

        def acuant_sdk_source?
          @image_source == ImageSources::ACUANT_SDK
        end

        def back_image_required?
          document_type_requested == DocumentTypes::DRIVERS_LICENSE
        end

        def image_cropping_mode
          # ImageCroppingMode values:
          # 0 = None (no cropping needed, images already cropped)
          # 1 = Automatic
          # 3 = Always (always crop, images are uncropped)
          @images_cropped ? 0 : 3
        end

        def encode(image)
          Base64.strict_encode64(image)
        end

        def metric_name
          'lexis_nexis_doc_auth_true_id'
        end

        def timeout
          IdentityConfig.store.lexisnexis_trueid_timeout
        end
      end
    end
  end
end
