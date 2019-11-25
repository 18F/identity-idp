module PhoneOtp
  OtpObject = Struct.new(:code, :sent_at, :delivery_method, keyword_init: true) do
    def self.generate_for_delivery_method(delivery_method)
      new(
        code: CodeGenerator.call,
        sent_at: Time.zone.now,
        delivery_method: delivery_method.to_sym,
      )
    end

    def to_h
      {
        code: code,
        sent_at: sent_at.to_i,
        delivery_method: delivery_method,
      }
    end

    def self.from_h(hash)
      new(
        code: hash[:code],
        sent_at: Time.zone.at(hash[:sent_at]),
        delivery_method: hash[:delivery_method].to_sym,
      )
    end

    def matches_code?(candidate_code)
      Devise.secure_compare(candidate_code, code)
    end

    def expired?
      expiration_time = sent_at + Figaro.env.otp_valid_for.to_i.minutes
      Time.zone.now > expiration_time
    end

    def sms?
      delivery_method == :sms
    end

    def voice?
      delivery_method == :voice
    end
  end
end
