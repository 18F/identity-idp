module DocAuth
  module Acuant
    module Requests
      class UploadImageRequest < DocAuth::Acuant::Request
        attr_reader :image_data, :instance_id, :side

        def initialize(config:, image_data:, instance_id:, side:)
          super(config:)
          @image_data = image_data
          @instance_id = instance_id
          @side = side
        end

        def path
          "/AssureIDService/Document/#{instance_id}/Image?side=#{side_param}&light=0"
        end

        def body
          image_data
        end

        def side_param
          {
            front: 0,
            back: 1,
          }[side.downcase.to_sym]
        end

        def handle_http_response(_response)
          DocAuth::Response.new(success: true)
        end

        def method
          :post
        end

        def metric_name
          'acuant_doc_auth_upload_image'
        end

        def timeout
          IdentityConfig.store.acuant_upload_image_timeout
        end

        def errors_from_http_status(status)
          case status
          when 438
            {
              general: [Errors::IMAGE_LOAD_FAILURE],
              side.downcase.to_sym => [Errors::IMAGE_LOAD_FAILURE_FIELD],
            }
          when 439
            {
              general: [Errors::PIXEL_DEPTH_FAILURE],
              side.downcase.to_sym => [Errors::PIXEL_DEPTH_FAILURE_FIELD],
            }
          when 440
            {
              general: [Errors::IMAGE_SIZE_FAILURE],
              side.downcase.to_sym => [Errors::IMAGE_SIZE_FAILURE_FIELD],
            }
          end
        end
      end
    end
  end
end
