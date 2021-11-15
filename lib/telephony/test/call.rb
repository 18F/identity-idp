module Telephony
  module Test
    class Call
      attr_reader :to, :body, :otp, :sent_at

      class << self
        def calls
          @calls ||= []
        end

        def clear_calls
          @calls = []
        end

        def last_otp(phone: nil)
          calls.reverse.find do |call|
            next false unless phone.nil? || call.to == phone

            true unless call.otp.nil?
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
