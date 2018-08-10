module Idv
  class PhoneConfirmationOtpVerificationForm
    attr_reader :user, :idv_session, :code

    def initialize(user:, idv_session:)
      @user = user
      @idv_session = idv_session
    end

    def submit(code:)
      @code = code
      success = code_valid?
      if success
        idv_session.user_phone_confirmation = true
        clear_second_factor_attempts
      else
        increment_second_factor_attempts
      end
      FormResponse.new(success: success, errors: {}, extra: extra_analytics_attributes)
    end

    private

    def code_valid?
      return false if code_expired?
      code_matches?
    end

    # Ignore duplicate method call on Time.zone :reek:DuplicateMethodCall
    def code_expired?
      sent_at_time = Time.zone.parse(idv_session.phone_confirmation_otp_sent_at)
      expiration_time = sent_at_time + Figaro.env.otp_valid_for.to_i.minutes
      Time.zone.now > expiration_time
    end

    def code_matches?
      Devise.secure_compare(code, idv_session.phone_confirmation_otp)
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
        code_expired: code_expired?,
        code_matches: code_matches?,
        second_factor_attempts_count: user.second_factor_attempts_count,
        second_factor_locked_at: user.second_factor_locked_at,
      }
    end
  end
end
