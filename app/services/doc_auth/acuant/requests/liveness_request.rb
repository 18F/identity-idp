module DocAuth
  module Acuant
    module Requests
      class LivenessRequest < DocAuth::Acuant::Request
        attr_reader :image

        def initialize(config:, image:)
          super(config: config)
          @image = image
        end

        def headers
          super.merge('Content-Type' => 'application/json')
        end

        def url
          URI.join(config.passlive_url, path)
        end

        def path
          '/api/v1/liveness'
        end

        def body
          {
            'Settings' => {
              'SubscriptionId' => config.assure_id_subscription_id,
              'AdditionalSettings' => { 'OS' => 'UNKNOWN' },
            },
            'Image' => Base64.strict_encode64(image),
          }.to_json
        end

        def handle_http_response(http_response)
          DocAuth::Acuant::Responses::LivenessResponse.new(http_response)
        end

        def method
          :post
        end

        def metric_name
          'acuant_doc_auth_liveness'
        end
      end
    end
  end
end
