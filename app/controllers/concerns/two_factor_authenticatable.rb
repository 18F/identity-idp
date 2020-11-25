module TwoFactorAuthenticatable
  extend ActiveSupport::Concern
  include TwoFactorAuthenticatableMethods

  NEED_AUTHENTICATION = 'need_two_factor_authentication'.freeze
  OTP_LENGTH = 6
  ALLOWED_OTP_DRIFT_SECONDS = 30
  DIRECT_OTP_VALID_FOR_SECONDS = AppConfig.env.otp_valid_for.to_i.minutes
  REMEMBER_2FA_COOKIE = 'remember_tfa'.freeze

  included do
    # rubocop:disable Rails/LexicallyScopedActionFilter
    before_action :authenticate_user
    before_action :require_current_password, if: :current_password_required?
    before_action :check_already_authenticated
    before_action :reset_attempt_count_if_user_no_longer_locked_out, only: :create
    before_action :apply_secure_headers_override, only: %i[show create]
    # rubocop:enable Rails/LexicallyScopedActionFilter
  end

  def self.direct_otp_length
    OTP_LENGTH
  end

  def self.otp_length
    OTP_LENGTH
  end

  def self.direct_otp_valid_for_seconds
    DIRECT_OTP_VALID_FOR_SECONDS
  end

  def self.allowed_otp_drift_seconds
    ALLOWED_OTP_DRIFT_SECONDS
  end
end
