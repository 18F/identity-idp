class MfaPolicy
  # :reek:BooleanParameter
  def initialize(user, signup = false)
    @mfa_user = MfaContext.new(user)
    @signup_flag = signup
  end

  def no_factors_enabled?
    mfa_user.enabled_mfa_methods_count.zero?
  end

  def two_factor_enabled?
    mfa_user.two_factor_configurations.any?(&:mfa_enabled?)
  end

  def multiple_factors_enabled?
    mfa_user.enabled_mfa_methods_count > 1
  end

  def more_than_two_factors_enabled?
    mfa_user.enabled_mfa_methods_count > 2
  end

  def sufficient_factors_enabled?
    mfa_user.enabled_mfa_methods_count > 1 ||
      (FeatureManagement.backup_codes_as_only_2fa? &&
      mfa_user.backup_code_configurations.to_a.length.positive? &&
      !signup_flag)
  end

  def unphishable?
    mfa_user.phishable_configuration_count.zero? &&
      mfa_user.unphishable_configuration_count.positive?
  end

  private

  attr_reader :mfa_user
  attr_reader :signup_flag
end
