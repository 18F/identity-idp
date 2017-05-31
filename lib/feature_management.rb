class FeatureManagement
  PT_DOMAIN_NAME = 'idp.pt.login.gov'.freeze

  def self.telephony_disabled?
    Figaro.env.telephony_disabled == 'true'
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
    Figaro.env.domain_name == PT_DOMAIN_NAME && telephony_disabled?
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
end
