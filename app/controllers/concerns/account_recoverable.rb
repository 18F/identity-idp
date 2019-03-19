module AccountRecoverable
  # :reek:FeatureEnvy
  def piv_cac_enabled_but_not_multiple_mfa_enabled?
    TwoFactorAuthentication::PivCacPolicy.new(current_user).enabled? &&
      !MfaPolicy.new(current_user).multiple_factors_enabled?
  end
end
