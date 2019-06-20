module Twilio
  FakeCall = Struct.new(:to, :from, :url, :record, :sent_at) do
    cattr_accessor :calls
    self.calls = []

    def self.create(opts)
      calls << FakeCall.new(
        opts[:to],
        opts[:from],
        opts[:url],
        opts[:record],
        Time.zone.now,
      )
    end

    def self.last_call(phone: nil)
      return calls.last if phone.nil?
      calls.select { |c| c.to == phone }.last
    end

    def self.last_otp(phone: nil)
      last_call(phone: phone)&.otp
    end

    def otp
      parsed_uri = URI.parse(url)
      params = CGI.parse(parsed_uri.query)
      encrypted_code = params['encrypted_code'].first
      cipher.decrypt(encrypted_code).to_s
    end

    private

    def cipher
      Gibberish::AES.new(Figaro.env.attribute_encryption_key)
    end
  end
end
