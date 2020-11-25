module PhoneConfirmation
  class ConfirmationSession
    attr_reader :code, :phone, :sent_at, :delivery_method

    def initialize(code:, phone:, sent_at:, delivery_method:)
      @code = code
      @phone = phone
      @sent_at = sent_at
      @delivery_method = delivery_method.to_sym
    end

    def self.start(phone:, delivery_method:)
      new(
        code: CodeGenerator.call,
        phone: phone,
        sent_at: Time.zone.now,
        delivery_method: delivery_method,
      )
    end

    def regenerate_otp
      self.class.new(
        code: CodeGenerator.call,
        phone: phone,
        sent_at: Time.zone.now,
        delivery_method: delivery_method,
      )
    end

    def matches_code?(candidate_code)
      Devise.secure_compare(candidate_code, code)
    end

    def expired?
      expiration_time = sent_at + TwoFactorAuthenticatable.direct_otp_valid_for_seconds
      Time.zone.now > expiration_time
    end

    def sms?
      delivery_method == :sms
    end

    def voice?
      delivery_method == :voice
    end

    def to_h
      {
        code: code,
        phone: phone,
        sent_at: sent_at.to_i,
        delivery_method: delivery_method,
      }
    end

    def self.from_h(hash)
      new(
        code: hash[:code],
        phone: hash[:phone],
        sent_at: Time.zone.at(hash[:sent_at]),
        delivery_method: hash[:delivery_method].to_sym,
      )
    end
  end
end
