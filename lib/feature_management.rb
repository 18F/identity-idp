class FeatureManagement
  def self.sms_disabled?
    Figaro.env.sms_disabled == 'true'
  end

  def self.saml_encryption_disabled?
    Figaro.env.saml_encryption_disabled == 'true'
  end

  def self.allow_third_party_auth?
    Figaro.env.allow_third_party_auth == 'yes'
  end

  def self.prefill_otp_codes?
    # In development, when SMS is disabled we pre-fill the correct codes so that
    # developers can log in without needing to configure SMS delivery.
    Rails.env.development? && FeatureManagement.sms_disabled?
  end
end
