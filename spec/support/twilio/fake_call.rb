module Twilio
  FakeCall = Struct.new(:to, :from, :url, :record) do
    cattr_accessor :calls
    self.calls = []

    def self.create(opts)
      calls << FakeCall.new(
        opts[:to],
        opts[:from],
        opts[:url],
        opts[:record],
      )
    end

    def self.last_otp(phone: nil)
      return calls.last.otp if phone.nil?
      call = calls.select { |c| c.to == phone }.last
      call&.otp
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
