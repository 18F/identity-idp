class FeatureManagement
  ENVS_WHERE_PREFILLING_OTP_ALLOWED = %w[
    idp.dev.login.gov idp.pt.login.gov idp.dev.identitysandbox.gov idp.pt.identitysandbox.gov
  ].freeze

  ENVS_WHERE_PREFILLING_USPS_CODE_ALLOWED = %w[
    idp.dev.login.gov idp.int.login.gov idp.qa.login.gov idp.pt.login.gov
    idp.dev.identitysandbox.gov idp.qa.identitysandbox.gov idp.int.identitysandbox.gov
    idp.pt.identitysandbox.gov
  ].freeze

  def self.telephony_disabled?
    Figaro.env.telephony_disabled == 'true'
  end

  def self.piv_cac_enabled?
    Figaro.env.piv_cac_enabled == 'true'
  end

  def self.identity_pki_disabled?
    env = Figaro.env
    env.identity_pki_disabled == 'true' ||
      !env.piv_cac_service_url ||
      !env.piv_cac_verify_token_url
  end

  def self.development_and_piv_cac_entry_enabled?
    # This controls if we try to hop over to identity-pki or just throw up
    # a screen asking for a Subject or one of a list of error conditions.
    Rails.env.development? && piv_cac_enabled? && identity_pki_disabled?
  end

  def self.prefill_otp_codes?
    # In development, when SMS is disabled we pre-fill the correct codes so that
    # developers can log in without needing to configure SMS delivery.
    # We also allow this in production on a single server that is used for load testing.
    development_and_telephony_disabled? || prefill_otp_codes_allowed_in_production?
  end

  def self.development_and_telephony_disabled?
    Rails.env.development? && telephony_disabled?
  end

  def self.prefill_otp_codes_allowed_in_production?
    ENVS_WHERE_PREFILLING_OTP_ALLOWED.include?(Figaro.env.domain_name) && telephony_disabled?
  end

  def self.enable_i18n_mode?
    Figaro.env.enable_i18n_mode == 'true'
  end

  def self.enable_load_testing_mode?
    Figaro.env.enable_load_testing_mode == 'true'
  end

  def self.password_strength_enabled?
    Figaro.env.password_strength_enabled == 'true'
  end

  def self.use_kms?
    Figaro.env.use_kms == 'true'
  end

  def self.use_dashboard_service_providers?
    Figaro.env.use_dashboard_service_providers == 'true'
  end

  def self.enable_identity_verification?
    Figaro.env.enable_identity_verification == 'true'
  end

  def self.enable_usps_verification?
    Figaro.env.enable_usps_verification == 'true'
  end

  def self.reveal_usps_code?
    Rails.env.development? || current_env_allowed_to_see_usps_code?
  end

  def self.current_env_allowed_to_see_usps_code?
    ENVS_WHERE_PREFILLING_USPS_CODE_ALLOWED.include?(Figaro.env.domain_name)
  end

  def self.no_pii_mode?
    enable_identity_verification? && Figaro.env.profile_proofing_vendor == :mock
  end

  def self.enable_saml_cert_rotation?
    Figaro.env.saml_secret_rotation_enabled == 'true'
  end

  def self.recaptcha_enabled?(session, reset)
    AbTest.new(:ab_test_recaptcha_enabled, Figaro.env.recaptcha_enabled_percent).
      enabled?(session, reset)
  end
end
