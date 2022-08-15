module UspsInPersonProofing
  module Response
    class RequestEnrollResponse
      attr_reader :enrollment_code, :expiration_date, :response_message

      def initialize(body)
        @body = body
        parse_response
      end

      private

      attr_reader :body
      attr_writer :enrollment_code, :expiration_date, :response_message

      def parse_response
        unless body.is_a?(Hash)
          raise StandardError.new("Expected a hash but got a #{body.class.class_name}")
        end

        unless body['enrollmentCode']
          raise StandardError.new('Expected to receive an enrollment code')
        end

        self.enrollment_code = body['enrollmentCode']
        self.expiration_date = body['expirationDate']
        self.response_message = body['responseMessage']
      end
    end
  end
end
