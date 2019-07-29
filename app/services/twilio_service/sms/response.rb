module TwilioService
  module Sms
    class Response
      MESSAGE_STOP_VARIANTS = %w[cancel end quit unsubscribe].freeze
      MESSAGE_TYPES = %w[help stop].concat(MESSAGE_STOP_VARIANTS).freeze
      SIGNATURE_HEADER = 'HTTP_X_TWILIO_SIGNATURE'.freeze

      # CTIA short code guidelines require support for multiple stop words
      MESSAGE_STOP_VARIANTS.each { |msg| define_method(msg) { send('stop') } }

      delegate :extra_analytics_attributes, to: :request

      def initialize(request)
        @request = request
      end

      def reply
        return unless request.valid?

        {
          to: request.from,
          body: send(request.message),
        }
      end

      private

      attr_reader :request

      def help
        I18n.t('sms.help.message')
      end

      def stop
        I18n.t('sms.stop.message')
      end
    end
  end
end
