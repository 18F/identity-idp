module Telephony
  module Test
    class Message
      attr_reader :to, :body, :otp, :sent_at

      class << self
        def messages
          @messages ||= []
        end

        def clear_messages
          @messages = []
        end

        def last_otp(phone: nil)
          messages.reverse.find do |messages|
            next false unless phone.nil? || messages.to == phone

            true unless messages.otp.nil?
          end&.otp
        end
      end

      def initialize(to:, body:, otp:, sent_at: Time.zone.now)
        @to = to
        @body = body
        @otp = otp
        @sent_at = sent_at
      end
    end
  end
end
