module Twilio
  FakeVerifyMessage = Struct.new(:country_code, :local_number, :code) do
    cattr_accessor :messages
    self.messages = []

    def self.create(opts)
      messages << FakeVerifyMessage.new(
        opts[:country_code],
        opts[:phone_number],
        opts[:custom_code],
      )
    end

    def self.last_otp(phone: nil)
      return messages.last&.otp if phone.nil?
      message = messages.select { |m| m.to == phone }.last
      message&.otp
    end

    def to
      PhoneFormatter.format("+#{country_code}#{local_number}")
    end

    def otp
      code
    end
  end
end
