module Twilio
  FakeMessage = Struct.new(:to, :body, :messaging_service_sid, :sent_at) do
    cattr_accessor :messages
    self.messages = []

    def self.create(opts)
      messages << FakeMessage.new(
        opts[:to],
        opts[:body],
        opts[:messaging_service_sid],
        Time.zone.now,
      )
    end

    def self.last_message(phone: nil)
      return messages.last if phone.nil?
      messages.select { |m| m.to == phone }.last
    end

    def self.last_otp(phone: nil)
      last_message(phone: phone)&.otp
    end

    def otp
      body[0, 6]
    end
  end
end
