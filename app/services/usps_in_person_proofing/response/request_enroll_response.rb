module UspsInPersonProofing
  module Response
    class RequestEnrollResponse
      attr_reader :enrollment_code, :expiration_date, :response_message

      def initialize(http_response)
        @http_response = http_response
        parse_response
      end

      private

      attr_reader :http_response
      attr_writer :enrollment_code, :expiration_date, :response_message

      def parse_response
        unless http_response.is_a?(Hash)
          raise StandardError.new("Expected a hash but got a #{http_response.class.class_name}")
        end

        unless http_response['enrollmentCode']
          raise StandardError.new('Expected to receive an enrollment code')
        end

        self.enrollment_code = http_response['enrollmentCode']
        self.expiration_date = http_response['expirationDate']
        self.response_message = http_response['responseMessage']
      end
    end
  end
end
