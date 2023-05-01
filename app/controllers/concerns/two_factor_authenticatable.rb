module TwoFactorAuthenticatable
  extend ActiveSupport::Concern
  include TwoFactorAuthenticatableMethods

  NEED_AUTHENTICATION = 'need_two_factor_authentication'.freeze
  OTP_LENGTH = 6
  DIRECT_OTP_LENGTH = 6
  PROOFING_DIRECT_OTP_LENGTH = 6
  ALLOWED_OTP_DRIFT_SECONDS = 30
  DIRECT_OTP_VALID_FOR_MINUTES = IdentityConfig.store.otp_valid_for
  DIRECT_OTP_VALID_FOR_SECONDS = DIRECT_OTP_VALID_FOR_MINUTES * 60
  REMEMBER_2FA_COOKIE = 'remember_tfa'.freeze
  AUTH_METHOD_BACKUP_CODE = 'backup_code'
  AUTH_METHOD_PERSONAL_KEY = 'personal_key'
  AUTH_METHOD_PIV_CAC = 'piv_cac'
  AUTH_METHOD_REMEMBER_DEVICE = 'remember_device'
  AUTH_METHOD_SMS = 'sms'
  AUTH_METHOD_TOTP = 'totp'
  AUTH_METHOD_VOICE = 'voice'
  AUTH_METHOD_WEBAUTHN = 'webauthn'
  AUTH_METHOD_WEBAUTHN_PLATFORM = 'webauthn_platform'

  included do
    # rubocop:disable Rails/LexicallyScopedActionFilter
    before_action :authenticate_user
    before_action :require_current_password, if: :current_password_required?
    before_action :check_already_authenticated
    before_action :reset_attempt_count_if_user_no_longer_locked_out, only: :create
    before_action :apply_secure_headers_override, only: %i[show create]
    # rubocop:enable Rails/LexicallyScopedActionFilter
  end
end
