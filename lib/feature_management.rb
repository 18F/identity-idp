class FeatureManagement
  def self.telephony_disabled?
    Figaro.env.telephony_disabled == 'true'
  end

  def self.allow_third_party_auth?
    Figaro.env.allow_third_party_auth == 'true'
  end

  def self.prefill_otp_codes?
    # In development, when SMS is disabled we pre-fill the correct codes so that
    # developers can log in without needing to configure SMS delivery.
    Rails.env.development? && FeatureManagement.telephony_disabled?
  end

  def self.enable_i18n_mode?
    Figaro.env.enable_i18n_mode == 'true'
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
end
