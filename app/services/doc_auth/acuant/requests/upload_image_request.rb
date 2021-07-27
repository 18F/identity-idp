require 'identity_doc_auth/acuant/request'
require 'identity_doc_auth/response'

module IdentityDocAuth
  module Acuant
    module Requests
      class UploadImageRequest < IdentityDocAuth::Acuant::Request
        attr_reader :image_data, :instance_id, :side

        def initialize(config:, image_data:, instance_id:, side:)
          super(config: config)
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
          IdentityDocAuth::Response.new(success: true)
        end

        def method
          :post
        end

        def metric_name
          'acuant_doc_auth_upload_image'
        end
      end
    end
  end
end
