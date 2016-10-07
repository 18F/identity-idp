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

  def self.proofing_requires_kbv?
    Figaro.env.proofing_kbv == 'true'
  end
end
