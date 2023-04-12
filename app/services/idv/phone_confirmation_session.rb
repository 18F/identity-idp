module Idv
  class PhoneConfirmationSession
    attr_reader :code, :phone, :sent_at, :delivery_method

    def self.generate_code
      OtpCodeGenerator.generate_alphanumeric_digits(
        TwoFactorAuthenticatable::PROOFING_DIRECT_OTP_LENGTH,
      )
    end

    def initialize(code:, phone:, sent_at:, delivery_method:)
      @code = code
      @phone = phone
      @sent_at = sent_at
      @delivery_method = delivery_method.to_sym
    end

    def self.start(phone:, delivery_method:)
      new(
        code: generate_code,
        phone: phone,
        sent_at: Time.zone.now,
        delivery_method: delivery_method,
      )
    end

    def regenerate_otp
      self.class.new(
        code: self.class.generate_code,
        phone: phone,
        sent_at: Time.zone.now,
        delivery_method: delivery_method,
      )
    end

    def matches_code?(candidate_code)
      return Devise.secure_compare(candidate_code, code) if code.nil? || candidate_code.nil?

      crockford_candidate_code = Base32::Crockford.normalize(candidate_code)
      crockford_code = Base32::Crockford.normalize(code)
      Devise.secure_compare(crockford_candidate_code, crockford_code)
    end

    def expired?
      expiration_time = sent_at + TwoFactorAuthenticatable::DIRECT_OTP_VALID_FOR_SECONDS
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
