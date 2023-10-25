# frozen_string_literal: true

module DocAuth
  module Acuant
    module Requests
      class CreateDocumentRequest < DocAuth::Acuant::Request
        def initialize(config:, image_source:)
          super(config: config)

          # @see DocAuth::ImageSources
          @image_source = image_source
        end

        def path
          '/AssureIDService/Document/Instance'
        end

        def headers
          super.merge('Content-Type' => 'application/json')
        end

        def body
          {
            AuthenticationSensitivity: 0,
            ClassificationMode: 0,
            Device: {
              HasContactlessChipReader: false,
              HasMagneticStripeReader: false,
              SerialNumber: 'xxxxx',
              Type: {
                Manufacturer: 'Login.gov',
                Model: 'Doc Auth 1.0',
                SensorType: sensor_type,
              },
            },
            ImageCroppingExpectedSize: '1',
            ImageCroppingMode: cropping_mode,
            ManualDocumentType: nil,
            ProcessMode: 0,
            SubscriptionId: config.assure_id_subscription_id,
          }.to_json
        end

        def handle_http_response(response)
          DocAuth::Acuant::Responses::CreateDocumentResponse.new(response)
        end

        def method
          :post
        end

        def metric_name
          'acuant_doc_auth_create_document'
        end

        def timeout
          IdentityConfig.store.acuant_create_document_timeout
        end

        private

        def acuant_sdk_source?
          @image_source == ImageSources::ACUANT_SDK
        end

        def cropping_mode
          if acuant_sdk_source?
            CroppingModes::NONE
          else
            CroppingModes::ALWAYS
          end
        end

        def sensor_type
          if acuant_sdk_source?
            SensorTypes::MOBILE
          else
            SensorTypes::UNKNOWN
          end
        end
      end
    end
  end
end
