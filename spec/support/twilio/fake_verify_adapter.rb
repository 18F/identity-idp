module Twilio
  class FakeVerifyAdapter
    class Request
      attr_accessor :body, :headers

      def initialize
        @headers = {}
      end

      def url(new_value = nil)
        @url = new_value if new_value.present?
        @url
      end
    end

    def self.post
      request = Request.new
      yield request
      Twilio::FakeVerifyMessage.create(request.body)
      SuccessResponse.new
    end

    class SuccessResponse
      def success?
        true
      end
    end

    class ErrorResponse
      def success?
        false
      end

      def body
        {
          error_code: '60033',
          message: 'Invalid number',
        }.to_json
      end

      def status
        400
      end
    end

    class EmptyResponse
      def success?
        false
      end

      def body
        ''
      end

      def status
        400
      end
    end
  end
end
