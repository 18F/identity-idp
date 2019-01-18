module TwilioService
  module Sms
    class Request
      MESSAGE_PARAM_BODY = 'Body'.freeze
      MESSAGE_PARAM_FROM = 'From'.freeze
      MESSAGE_PARAM_FROM_COUNTRY = 'FromCountry'.freeze
      MESSAGE_PARAM_MESSAGE_SID = 'MessageSid'.freeze # Twilio ID
      SIGNATURE_HEADER = 'HTTP_X_TWILIO_SIGNATURE'.freeze

      def initialize(url, params, signature)
        @url = url
        @params = params.reject { |key| key.downcase == key }
        @signature = signature
      end

      def valid?
        signature_valid? && message_valid?
      end

      def message
        @message ||= params[Request::MESSAGE_PARAM_BODY.to_sym]&.downcase
      end

      def from
        @from = params[Request::MESSAGE_PARAM_FROM.to_sym]
      end

      def extra_analytics_attributes
        {
          message_sid: params[Request::MESSAGE_PARAM_MESSAGE_SID.to_sym],
          from_country: params[Request::MESSAGE_PARAM_FROM_COUNTRY.to_sym],
        }
      end

      # First, validate the message signature using Twilio's library:
      # https://github.com/twilio/twilio-ruby/wiki/Request-Validator
      def signature_valid?
        Twilio::Security::RequestValidator.new(
          Figaro.env.twilio_auth_token,
        ).validate(url, params, signature)
      end

      def message_valid?
        message.present? && Response::MESSAGE_TYPES.include?(message)

        # We may also want to validate the 'From' number against existing Users
        # before processing the submission; however this is on-hold during the
        # initial phase.
      end

      private

      attr_reader :url, :params, :signature
    end
  end
end
