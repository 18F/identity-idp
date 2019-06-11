module Twilio
  FakeMessage = Struct.new(:to, :body, :messaging_service_sid) do
    cattr_accessor :messages
    self.messages = []

    def self.create(opts)
      messages << FakeMessage.new(
        opts[:to],
        opts[:body],
        opts[:messaging_service_sid],
      )
    end

    def self.last_otp(phone: nil)
      return messages.last&.otp if phone.nil?
      message = messages.select { |m| m.to == phone }.last
      message&.otp
    end

    def otp
      body[0, 6]
    end
  end
end
