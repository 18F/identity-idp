# frozen_string_literal: true

module Telephony
  module Test
    class VoiceSender
      ORIGINATION_PHONE_NUMBER = '+1888LOGINGOV'

      # rubocop:disable Lint/UnusedMethodArgument
      def send(message:, to:, country_code:, otp: nil)
        error = ErrorSimulator.new.error_for_number(to)
        if error.nil?
          Call.calls.push(Call.new(body: message, to: to, otp: otp))
          Response.new(
            success: true,
            extra: {
              request_id: 'fake-message-request-id',
              origination_phone_number: ORIGINATION_PHONE_NUMBER,
            },
          )
        else
          Response.new(
            success: false,
            error: error,
            extra: {
              request_id: 'fake-message-request-id',
              origination_phone_number: ORIGINATION_PHONE_NUMBER,
            },
          )
        end
      end
      # rubocop:enable Lint/UnusedMethodArgument
    end
  end
end
