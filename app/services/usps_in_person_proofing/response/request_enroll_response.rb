module UspsInPersonProofing
  module Response
    class RequestEnrollResponse
      attr_reader :enrollment_code, :expiration_date, :response_message

      def initialize(http_response)
        @http_response = http_response
        handle_http_error
        parse_response
      end

      private

      attr_reader :http_response
      attr_writer :enrollment_code, :expiration_date, :response_message

      def parse_response
        data = JSON.parse(response.body)

        unless data.is_a?(Hash)
          raise StandardError.new("Expected a hash but got a #{data.class.class_name}")
        end

        unless data['enrollmentCode']
          raise StandardError.new('Expected to receive an nrollment code')
        end

        self.enrollment_code = data['enrollmentCode']
        self.expiration_date = data['expirationDate']
        self.response_message = data['responseMessage']
      end
    end
  end
end
