class MfaPolicy
  def initialize(user)
    @user = user
    @mfa_user = MfaContext.new(user)
  end

  def no_factors_enabled?
    mfa_user.enabled_mfa_methods_count.zero?
  end

  # TODO: Rename this mfa_enabled?
  def two_factor_enabled?
    mfa_user.two_factor_configurations.any?(&:mfa_enabled?)
  end

  def multiple_factors_enabled?
    mfa_user.enabled_mfa_methods_count > 1
  end

  # TODO: get rid of this and use multiple factors enabled
  def more_than_two_factors_enabled?
    mfa_user.enabled_mfa_methods_count > 2
  end

  # Current stack
  # TODO Get rid of this and use two_factor_enabled?
  def sufficient_factors_enabled?
    mfa_user.enabled_mfa_methods_count >= 1 ||
      mfa_user.backup_code_configurations.to_a.length.positive?
  end

  def unphishable?
    mfa_user.phishable_configuration_count.zero? &&
      mfa_user.unphishable_configuration_count.positive?
  end

  private

  attr_reader :mfa_user
end
