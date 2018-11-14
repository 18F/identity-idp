module AccountRecoverable
  # :reek:FeatureEnvy
  def piv_cac_enabled_but_not_multiple_mfa_enabled?
    # we need to change this so it's about having multiple mfa methods defined rather than
    # piv/cac + phone. Leaving as-is for now.
    TwoFactorAuthentication::PivCacPolicy.new(current_user).enabled? &&
      !MfaPolicy.new(current_user).multiple_factors_enabled?
  end
end
