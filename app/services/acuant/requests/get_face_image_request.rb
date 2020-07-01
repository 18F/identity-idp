module Acuant
  module Requests
    class GetFaceImageRequest < Acuant::Request
      attr_reader :instance_id

      def initialize(instance_id:)
        @instance_id = instance_id
      end

      def path
        "/AssureIDService/Document/#{instance_id}/Field/Image?key=Photo"
      end

      def handle_http_response(http_response)
        Responses::GetFaceImageResponse.new(http_response)
      end

      def method
        :get
      end
    end
  end
end
