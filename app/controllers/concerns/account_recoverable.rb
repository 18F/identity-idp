module AccountRecoverable
  # :reek:FeatureEnvy
  def piv_cac_enabled_but_not_phone_enabled?
    current_user.two_factor_enabled?([:piv_cac]) && !current_user.two_factor_enabled?(%i[sms voice])
  end
end
