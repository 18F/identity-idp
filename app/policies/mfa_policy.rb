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

  # Move counts to MfaContext.
  def unphishable?
    mfa_user.unphishable?
  end

  private

  attr_reader :mfa_user
end
