class FeatureManagement
  def self.pt_mode?
    Figaro.env.pt_mode == 'on'
  end

  def self.allow_enterprise_auth?
    Figaro.env.allow_enterprise_auth == 'yes' || Rails.env.test?
  end
end
