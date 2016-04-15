class FeatureManagement
  def self.pt_mode?
    Figaro.env.pt_mode == 'on'
  end

  def self.allow_third_party_auth?
    Figaro.env.allow_third_party_auth == 'yes'
  end
end
