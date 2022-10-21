module Idv
  class PhoneConfirmationOtpVerificationForm
    attr_reader :user, :user_phone_confirmation_session, :irs_attempts_api_tracker, :code

    def initialize(user:, user_phone_confirmation_session:, irs_attempts_api_tracker:)
      @user = user
      @user_phone_confirmation_session = user_phone_confirmation_session
      @irs_attempts_api_tracker = irs_attempts_api_tracker
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
      UpdateUser.new(user: user, attributes: { second_factor_attempts_count: 0 }).call
    end

    def increment_second_factor_attempts
      user.second_factor_attempts_count += 1
      attributes = {}
      if user.max_login_attempts?
        attributes[:second_factor_locked_at] = Time.zone.now
        irs_attempts_api_tracker.idv_phone_otp_submitted_rate_limited(phone_number: user_phone)
      end

      UpdateUser.new(user: user, attributes: attributes).call
    end

    def user_phone
      user_phone_confirmation_session.phone
    end

    def extra_analytics_attributes
      {
        code_expired: user_phone_confirmation_session.expired?,
        code_matches: user_phone_confirmation_session.matches_code?(code),
        second_factor_attempts_count: user.second_factor_attempts_count,
        second_factor_locked_at: user.second_factor_locked_at,
      }
    end
  end
end
