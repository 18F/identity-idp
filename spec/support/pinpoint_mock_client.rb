module Pinpoint
  class MockClient
    include ::RSpec::Matchers

    class << self
      attr_accessor :last_request
      attr_accessor :message_response_request_id
      attr_accessor :message_response_result_status_code
      attr_accessor :message_response_result_delivery_status
      attr_accessor :message_response_result_status_message
      attr_accessor :message_response_result_message_id

      def reset!
        self.last_request = nil
        self.message_response_request_id = 'fake-message-request-id'
        self.message_response_result_status_code = 200
        self.message_response_result_delivery_status = 'SUCCESSFUL'
        self.message_response_result_message_id = 'fake-message-id'
        self.message_response_result_status_message = "MessageId: "\
        "#{self.message_response_result_message_id}"
      end
    end

    Response = Struct.new(:message_response)
    MessageResponse = Struct.new(:result, :request_id)
    MessageResponseResult = Struct.new(
      :status_code,
      :delivery_status,
      :status_message,
      :message_id,
    )

    attr_reader :config

    def initialize(config)
      @config = config
    end

    def send_messages(request)
      expect(request[:application_id]).to eq(config.application_id)

      self.class.last_request = request

      addresses = request.dig(:message_request, :addresses).keys
      expect(addresses.length).to eq(1)
      recipient_phone = addresses.first

      result_hash = {
        recipient_phone => MessageResponseResult.new(
          self.class.message_response_result_status_code,
          self.class.message_response_result_delivery_status,
          self.class.message_response_result_status_message,
          self.class.message_response_result_message_id,
        ),
      }
      Response.new(MessageResponse.new(result_hash, self.class.message_response_request_id))
    end
  end
end
