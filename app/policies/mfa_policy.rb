class MfaPolicy
  def initialize(user)
    @user = user
    @mfa_user = MfaContext.new(user)
  end

  def two_factor_enabled?
    mfa_user.two_factor_enabled?
  end

  def phishing_resistant_mfa_enabled?
    mfa_user.piv_cac_configurations.present? ||
      mfa_user.webauthn_configurations.present?
  end

  def multiple_factors_enabled?
    mfa_user.enabled_mfa_methods_count > 1
  end

  def unphishable?
    mfa_user.phishable_configuration_count.zero? &&
      mfa_user.unphishable_configuration_count.positive?
  end

  def ft_unlock_only?
    mfa_user.webauthn_platform_configurations.count == 1 &&
      mfa_user.enabled_mfa_methods_count == 1
  end

  private

  attr_reader :mfa_user
end
