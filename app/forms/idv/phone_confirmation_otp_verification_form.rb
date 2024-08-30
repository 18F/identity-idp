# frozen_string_literal: true

module Idv
  class PhoneConfirmationOtpVerificationForm
    attr_reader :user, :user_phone_confirmation_session, :code

    def initialize(user:, user_phone_confirmation_session:)
      @user = user
      @user_phone_confirmation_session = user_phone_confirmation_session
    end

    def submit(code:)
      @code = code
      success = code_valid?
      if success
        clear_second_factor_attempts
      else
        increment_second_factor_attempts
      end
      FormResponse.new(success: success, extra: extra_analytics_attributes)
    end

    private

    def code_valid?
      return false if user_phone_confirmation_session.expired?
      user_phone_confirmation_session.matches_code?(code)
    end

    def clear_second_factor_attempts
      user.update!(second_factor_attempts_count: 0)
    end

    def increment_second_factor_attempts
      user.increment_second_factor_attempts_count!
    end

    def user_phone
      user_phone_confirmation_session.phone
    end

    def extra_analytics_attributes
      {
        code_expired: user_phone_confirmation_session.expired?,
        code_matches: user_phone_confirmation_session.matches_code?(code),
        otp_delivery_preference: user_phone_confirmation_session.delivery_method,
        second_factor_attempts_count: user.second_factor_attempts_count,
        second_factor_locked_at: user.second_factor_locked_at,
      }
    end
  end
end
