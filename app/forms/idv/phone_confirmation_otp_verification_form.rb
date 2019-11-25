module Idv
  class PhoneConfirmationOtpVerificationForm
    attr_reader :user, :phone_confirmation_otp, :code

    def initialize(user:, phone_confirmation_otp:)
      @user = user
      @phone_confirmation_otp = phone_confirmation_otp
    end

    def submit(code:)
      @code = code
      success = code_valid?
      if success
        clear_second_factor_attempts
      else
        increment_second_factor_attempts
      end
      FormResponse.new(success: success, errors: {}, extra: extra_analytics_attributes)
    end

    private

    def code_valid?
      return false if phone_confirmation_otp.expired?
      phone_confirmation_otp.matches_code?(code)
    end

    def clear_second_factor_attempts
      UpdateUser.new(user: user, attributes: { second_factor_attempts_count: 0 }).call
    end

    def increment_second_factor_attempts
      user.second_factor_attempts_count += 1
      attributes = {}
      attributes[:second_factor_locked_at] = Time.zone.now if user.max_login_attempts?

      UpdateUser.new(user: user, attributes: attributes).call
    end

    def extra_analytics_attributes
      {
        code_expired: phone_confirmation_otp.expired?,
        code_matches: phone_confirmation_otp.matches_code?(code),
        second_factor_attempts_count: user.second_factor_attempts_count,
        second_factor_locked_at: user.second_factor_locked_at,
      }
    end
  end
end
