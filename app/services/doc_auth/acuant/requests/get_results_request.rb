module DocAuth
  module Acuant
    module Requests
      class GetResultsRequest < DocAuth::Acuant::Request
        attr_reader :instance_id

        def initialize(config:, instance_id:)
          super(config: config)
          @instance_id = instance_id
        end

        def path
          "/AssureIDService/Document/#{instance_id}"
        end

        def headers
          super.merge('Content-Type' => 'application/json')
        end

        def handle_http_response(http_response)
          DocAuth::Acuant::Responses::GetResultsResponse.new(http_response, config)
        end

        def method
          :get
        end

        def metric_name
          'acuant_doc_auth_get_results'
        end

        def timeout
          IdentityConfig.store.acuant_get_results_timeout
        end

        def errors_from_http_status(status)
          case status
          when 438
            {
              general: [Errors::IMAGE_LOAD_FAILURE],
              front: [Errors::IMAGE_LOAD_FAILURE_FIELD],
              back: [Errors::IMAGE_LOAD_FAILURE_FIELD],
            }
          when 439
            {
              general: [Errors::PIXEL_DEPTH_FAILURE],
              front: [Errors::PIXEL_DEPTH_FAILURE_FIELD],
              back: [Errors::PIXEL_DEPTH_FAILURE_FIELD],
            }
          when 440
            {
              general: [Errors::IMAGE_SIZE_FAILURE],
              front: [Errors::IMAGE_SIZE_FAILURE_FIELD],
              back: [Errors::IMAGE_SIZE_FAILURE_FIELD],
            }
          end
        end
      end
    end
  end
end
