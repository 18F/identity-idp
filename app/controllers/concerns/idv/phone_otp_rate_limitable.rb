# frozen_string_literal: true

module Idv
  module PhoneOtpRateLimitable
    extend ActiveSupport::Concern

    include IdvSessionConcern

    included do
      before_action :handle_locked_out_user
    end

    def handle_locked_out_user
      reset_attempt_count_if_user_no_longer_locked_out
      return unless current_user.locked_out?
      analytics.idv_phone_confirmation_otp_rate_limit_locked_out
      handle_too_many_otp_attempts
      false
    end

    def reset_attempt_count_if_user_no_longer_locked_out
      return unless current_user.no_longer_locked_out?

      current_user.update!(
        second_factor_attempts_count: 0,
        second_factor_locked_at: nil,
      )
    end

    def handle_too_many_otp_sends
      analytics.idv_phone_confirmation_otp_rate_limit_sends
      attempts_api_tracker.idv_rate_limited(
        limiter_type: :phone_otp,
        phone_number:,
      )
      fraud_ops_tracker.idv_rate_limited(
        limiter_type: :phone_otp,
        phone_number:,
      )
      handle_max_attempts('otp_requests')
    end

    def handle_too_many_otp_attempts
      analytics.idv_phone_confirmation_otp_rate_limit_attempts
      attempts_api_tracker.idv_rate_limited(
        limiter_type: :phone_otp,
        phone_number:,
      )
      fraud_ops_tracker.idv_rate_limited(
        limiter_type: :phone_otp,
        phone_number:,
      )
      handle_max_attempts('otp_login_attempts')
    end

    def handle_max_attempts(type)
      presenter = TwoFactorAuthCode::MaxAttemptsReachedPresenter.new(
        type,
        current_user,
      )
      render_full_width('two_factor_authentication/_locked', locals: { presenter: presenter })
    end

    def phone_number
      if idv_session&.user_phone_confirmation_session&.phone.present?
        Phonelib.parse(idv_session.user_phone_confirmation_session.phone).e164
      end
    end
  end
end
