module Idv
  module PhoneOtpRateLimitable
    extend ActiveSupport::Concern

    included do
      before_action :confirm_two_factor_authenticated
      before_action :handle_locked_out_user
    end

    def handle_locked_out_user
      reset_attempt_count_if_user_no_longer_locked_out
      return unless decorated_user.locked_out?
      analytics.track_event(Analytics::IDV_PHONE_CONFIRMATION_OTP_RATE_LIMIT_LOCKED_OUT)
      handle_too_many_otp_attempts
      false
    end

    def reset_attempt_count_if_user_no_longer_locked_out
      return unless decorated_user.no_longer_locked_out?

      UpdateUser.new(
        user: current_user,
        attributes: {
          second_factor_attempts_count: 0,
          second_factor_locked_at: nil,
        },
      ).call
    end

    def handle_too_many_otp_sends
      analytics.track_event(Analytics::IDV_PHONE_CONFIRMATION_OTP_RATE_LIMIT_SENDS)
      handle_max_attempts('otp_requests')
    end

    def handle_too_many_otp_attempts
      analytics.track_event(Analytics::IDV_PHONE_CONFIRMATION_OTP_RATE_LIMIT_ATTEMPTS)
      handle_max_attempts('otp_login_attempts')
    end

    def handle_max_attempts(type)
      presenter = TwoFactorAuthCode::MaxAttemptsReachedPresenter.new(
        type,
        decorated_user,
      )
      sign_out
      render_full_width('shared/_failure', locals: { presenter: presenter })
    end

    def decorated_user
      current_user.decorate
    end
  end
end
