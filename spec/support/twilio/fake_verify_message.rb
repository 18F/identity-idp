module Twilio
  FakeVerifyMessage = Struct.new(:country_code, :local_number, :code, :sent_at) do
    cattr_accessor :messages
    self.messages = []

    def self.create(opts)
      messages << FakeVerifyMessage.new(
        opts[:country_code],
        opts[:phone_number],
        opts[:custom_code],
      )
    end

    def self.last_message(phone: nil)
      return messages.last if phone.nil?
      messages.select { |m| m.to == phone }.last
    end

    def self.last_otp(phone: nil)
      last_message(phone: phone)&.otp
    end

    def to
      PhoneFormatter.format("+#{country_code}#{local_number}")
    end

    def otp
      code
    end
  end
end
