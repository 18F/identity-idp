class FeatureManagement
  def self.pt_mode?
    Figaro.env.pt_mode == 'on'
  end

  def self.allow_ent_icam_auth?
    Figaro.env.allow_ent_icam_auth == 'yes' || Rails.env.test?
  end
end
