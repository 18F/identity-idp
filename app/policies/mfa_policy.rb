class MfaPolicy
  def initialize(user)
    @mfa_user = MfaContext.new(user)
  end

  def two_factor_enabled?
    mfa_user.two_factor_configurations.any?(&:mfa_enabled?)
  end

  def multiple_factors_enabled?
    mfa_user.enabled_mfa_methods_count > 1
  end

  def unphishable?
    mfa_user.phishable_configuration_count.zero? &&
      mfa_user.unphishable_configuration_count.positive?
  end

  def more_than_two_factors_enabled?
    mfa_user.enabled_mfa_methods_count > 2
  end

  def multiple_auth_methods_required_and_met?
    FeatureManagement.force_multiple_auth_methods? && multiple_factors_enabled?
  end

  def auth_methods_satisfied?
    multiple_auth_methods_required_and_met? ||
      (!FeatureManagement.force_multiple_auth_methods? && two_factor_enabled?)
  end

  def oversufficient_methods_enabled?
    return more_than_two_factors_enabled? if FeatureManagement.force_multiple_auth_methods?
    multiple_factors_enabled?
  end

  private

  attr_reader :mfa_user
end
