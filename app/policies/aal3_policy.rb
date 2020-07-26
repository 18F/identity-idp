class AAL3Policy
  AAL3_METHODS = %w[webauthn piv_cac].freeze

  attr_reader :mfa_policy, :auth_method, :service_provider, :aal_level_requested

  def initialize(
    user:,
    service_provider:,
    auth_method:,
    aal_level_requested:
  )
    @mfa_policy = MfaPolicy.new(user)
    @auth_method = auth_method
    @service_provider = service_provider
    @aal_level_requested = aal_level_requested
  end

  def aal3_required?
    aal3_requested? || aal3_configured?
  end

  def aal3_used?
    AAL3_METHODS.include?(auth_method)
  end

  def aal3_required_but_not_used?
    aal3_required? && !aal3_used?
  end

  def aal3_configured_but_not_used?
    aal3_configured_and_required? &&
      !aal3_used?
  end

  def aal3_configured_and_required?
    aal3_required? && @mfa_policy&.aal3_mfa_enabled?
  end

  private

  def aal3_requested?
    aal_level_requested == 3
  end

  def aal3_configured?
    return false if service_provider.blank?

    service_provider.aal == 3
  end
end
