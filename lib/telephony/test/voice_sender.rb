module Telephony
  module Test
    class VoiceSender
      # rubocop:disable Lint/UnusedMethodArgument
      def send(message:, to:, country_code:, otp: nil)
        error = ErrorSimulator.new.error_for_number(to)
        if error.nil?
          Call.calls.push(Call.new(body: message, to: to, otp: otp))
          Response.new(success: true, extra: { request_id: 'fake-message-request-id' })
        else
          Response.new(
            success: false, error: error, extra: { request_id: 'fake-message-request-id' },
          )
        end
      end
      # rubocop:enable Lint/UnusedMethodArgument
    end
  end
end
