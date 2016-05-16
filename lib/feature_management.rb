class FeatureManagement
  def self.sms_disabled?
    Figaro.env.sms_disabled == 'true'
  end

  def self.allow_third_party_auth?
    Figaro.env.allow_third_party_auth == 'yes'
  end
end
