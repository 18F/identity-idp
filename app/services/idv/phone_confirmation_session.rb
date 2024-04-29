# frozen_string_literal: true

module Idv
  class PhoneConfirmationSession
    attr_reader :code, :phone, :sent_at, :delivery_method, :user

    def self.generate_code(user:)
      bucket = AbTests::IDV_TEN_DIGIT_OTP.bucket(user&.uuid)
      case bucket
      when :ten_digit_otp
        OtpCodeGenerator.generate_digits(
          IdentityConfig.store.ab_testing_idv_ten_digit_otp_length,
        )
      else # original, bucket defaults to :six_alphanumeric_otp
        OtpCodeGenerator.generate_alphanumeric_digits(
          TwoFactorAuthenticatable::PROOFING_DIRECT_OTP_LENGTH,
        )
      end
    end

    def initialize(code:, phone:, sent_at:, delivery_method:, user:)
      @code = code
      @phone = phone
      @sent_at = sent_at
      @delivery_method = delivery_method.to_sym
      @user = user
    end

    def self.start(phone:, delivery_method:, user:)
      new(
        code: generate_code(user: user),
        phone: phone,
        sent_at: Time.zone.now,
        delivery_method: delivery_method,
        user: user,
      )
    end

    def ab_test_analytics_args
      return {} unless IdentityConfig.store.ab_testing_idv_ten_digit_otp_enabled

      {
        AbTests::IDV_TEN_DIGIT_OTP.experiment_name => {
          bucket: AbTests::IDV_TEN_DIGIT_OTP.bucket(user.uuid),
        },
      }
    end

    def regenerate_otp
      self.class.new(
        code: self.class.generate_code(user: user),
        phone: phone,
        sent_at: Time.zone.now,
        delivery_method: delivery_method,
        user: user,
      )
    end

    def matches_code?(candidate_code)
      return Devise.secure_compare(candidate_code, code) if code.nil? || candidate_code.nil?

      crockford_candidate_code = Base32::Crockford.normalize(candidate_code.sub(/^#/, ''))
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
        user: user&.id,
      }
    end

    def self.from_h(hash)
      new(
        code: hash[:code],
        phone: hash[:phone],
        sent_at: Time.zone.at(hash[:sent_at]),
        delivery_method: hash[:delivery_method].to_sym,
        user: hash[:user].nil? ? nil : User.find(hash[:user]),
      )
    end
  end
end
