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

  class AuthMethod
    BACKUP_CODE = 'backup_code'
    PERSONAL_KEY = 'personal_key'
    PIV_CAC = 'piv_cac'
    REMEMBER_DEVICE = 'remember_device'
    SMS = 'sms'
    TOTP = 'totp'
    VOICE = 'voice'
    WEBAUTHN = 'webauthn'
    WEBAUTHN_PLATFORM = 'webauthn_platform'

    PHISHING_RESISTANT_METHODS = [
      WEBAUTHN,
      WEBAUTHN_PLATFORM,
      PIV_CAC,
    ].to_set.freeze

    def self.phishing_resistant?(auth_method)
      PHISHING_RESISTANT_METHODS.include?(auth_method)
    end
  end

  included do
    # rubocop:disable Rails/LexicallyScopedActionFilter
    before_action :authenticate_user
    before_action :check_already_authenticated
    before_action :reset_attempt_count_if_user_no_longer_locked_out, only: :create
    before_action :apply_secure_headers_override, only: %i[show create]
    # rubocop:enable Rails/LexicallyScopedActionFilter
  end
end
