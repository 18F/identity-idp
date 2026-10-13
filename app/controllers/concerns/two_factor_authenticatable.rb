# frozen_string_literal: true

module TwoFactorAuthenticatable
  extend ActiveSupport::Concern
  include TwoFactorAuthenticatableMethods

  NEED_AUTHENTICATION = 'need_two_factor_authentication'
  OTP_LENGTH = 6
  DIRECT_OTP_LENGTH = 6
  PROOFING_SMS_DIRECT_OTP_LENGTH = 6
  PROOFING_VOICE_DIRECT_OTP_LENGTH = 10
  ALLOWED_OTP_DRIFT_SECONDS = 30
  DIRECT_OTP_VALID_FOR_MINUTES = IdentityConfig.store.otp_valid_for.freeze
  DIRECT_OTP_VALID_FOR_SECONDS = DIRECT_OTP_VALID_FOR_MINUTES * 60
  REMEMBER_2FA_COOKIE = 'remember_tfa'

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
    before_action :redirect_recovery_authentication_to_setup
    before_action :check_already_authenticated
    before_action :reset_attempt_count_if_user_no_longer_locked_out, only: :create
    before_action :apply_secure_headers_override, only: %i[show create]
    # rubocop:enable Rails/LexicallyScopedActionFilter
  end

  def redirect_recovery_authentication_to_setup
    return unless replacement_mfa_pending?
    if UserSessionContext.confirmation_context?(context) &&
       %w[users/two_factor_authentication two_factor_authentication/otp_verification
          two_factor_authentication/sms_opt_in].include?(controller_path)
      return
    end

    redirect_to account_recovery_new_mfa_setup_url
  end
end
