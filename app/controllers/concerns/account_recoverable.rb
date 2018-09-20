module AccountRecoverable
  # :reek:FeatureEnvy
  def piv_cac_enabled_but_not_phone_enabled?
    # we need to change this so it's about having multiple mfa methods defined rather than
    # piv/cac + phone. Leaving as-is for now.
    TwoFactorAuthentication::PivCacPolicy.new(current_user).enabled? &&
      !TwoFactorAuthentication::PhonePolicy.new(current_user).enabled?
  end
end
