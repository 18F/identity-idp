module AccountRecoverable
  # :reek:FeatureEnvy
  def piv_cac_enabled_but_not_phone_enabled?
    manager = TwoFactorAuthentication::MethodManager.new(current_user)
    manager.two_factor_enabled?([:piv_cac]) && !manager.two_factor_enabled?(%i[sms voice])
  end
end
