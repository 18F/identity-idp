module DocAuth
  module Acuant
    module Requests
      class CreateDocumentRequest < DocAuth::Acuant::Request
        def path
          '/AssureIDService/Document/Instance'
        end

        def headers
          super().merge 'Content-Type' => 'application/json'
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
                SensorType: '3',
              },
            },
            ImageCroppingExpectedSize: '1',
            ImageCroppingMode: '1',
            ManualDocumentType: nil,
            ProcessMode: 0,
            SubscriptionId: Figaro.env.acuant_assure_id_subscription_id,
          }.to_json
        end

        def handle_http_response(response)
          DocAuth::Acuant::Responses::CreateDocumentResponse.new(response)
        end

        def method
          :post
        end
      end
    end
  end
end
