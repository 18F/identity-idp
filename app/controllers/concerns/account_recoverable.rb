module AccountRecoverable
  # :reek:FeatureEnvy
  def piv_cac_enabled_but_not_phone_enabled?
    mfa = current_user.mfa
    # we need to change this so it's about having multiple mfa methods defined rather than
    # piv/cac + phone. Leaving as-is for now.
    mfa.piv_cac_configuration.mfa_enabled? && mfa.phone_configurations.none?(&:mfa_enabled?)
  end
end
