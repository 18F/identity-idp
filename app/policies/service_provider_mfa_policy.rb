class ServiceProviderMfaPolicy
  AAL3_METHODS = %w[webauthn piv_cac].freeze

  attr_reader :mfa_context, :auth_method, :service_provider

  def initialize(
    user:,
    service_provider:,
    auth_method:,
    aal_level_requested:,
    piv_cac_requested:
  )
    @user = user
    @mfa_context = MfaContext.new(user)
    @auth_method = auth_method
    @service_provider = service_provider
    @aal_level_requested = aal_level_requested
    @piv_cac_requested = piv_cac_requested
  end

  def user_needs_sp_auth_method_verification?
    # If the user needs to setup a new MFA method, return false so they go to
    # setup instead of verification
    return false if user_needs_sp_auth_method_setup?

    if piv_cac_required?
      auth_method.to_s != 'piv_cac'
    elsif aal3_required?
      !AAL3_METHODS.include?(auth_method.to_s)
    else
      false
    end
  end

  def user_needs_sp_auth_method_setup?
    return true if piv_cac_required? && !piv_cac_enabled?
    return true if aal3_required? && !aal3_enabled?
    false
  end

  def auth_method_confirms_to_sp_request?
    !user_needs_sp_auth_method_setup? && !user_needs_sp_auth_method_verification?
  end

  def aal3_required?
    aal3_requested? || service_provider&.aal == 3
  end

  def piv_cac_required?
    piv_cac_requested?
  end

  def allow_user_to_switch_method?
    return false if piv_cac_required?
    return true unless aal3_required?
    piv_cac_enabled? && webauthn_enabled?
  end

  private

  def aal3_enabled?
    piv_cac_enabled? || webauthn_enabled?
  end

  def aal3_requested?
    @aal_level_requested == 3
  end

  def piv_cac_enabled?
    mfa_context.piv_cac_configurations.any?(&:mfa_enabled?)
  end

  def piv_cac_requested?
    @piv_cac_requested
  end

  def webauthn_enabled?
    mfa_context.webauthn_configurations.any?(&:mfa_enabled?)
  end
end
