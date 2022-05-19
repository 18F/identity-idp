class MfaPolicy
  def initialize(user)
    @user = user
    @mfa_user = MfaContext.new(user)
  end

  def two_factor_enabled?
    mfa_user.two_factor_enabled?
  end

  def aal3_mfa_enabled?
    mfa_user.piv_cac_configurations.present? ||
      mfa_user.webauthn_configurations.present?
  end

  def multiple_factors_enabled?
    mfa_user.enabled_mfa_methods_count > 1
  end

  def multiple_non_restricted_factors_enabled?
    IdentityConfig.store.select_multiple_mfa_options ?
      mfa_user.enabled_non_restricted_mfa_methods_count > 1 :
      multiple_factors_enabled?
  end

  def unphishable?
    mfa_user.phishable_configuration_count.zero? &&
      mfa_user.unphishable_configuration_count.positive?
  end

  private

  attr_reader :mfa_user
end
