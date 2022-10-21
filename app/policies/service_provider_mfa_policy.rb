class ServiceProviderMfaPolicy
  PHISHING_RESISTANT_METHODS = %w[webauthn webauthn_platform piv_cac].freeze

  attr_reader :mfa_context, :auth_method, :service_provider

  def initialize(
    user:,
    service_provider:,
    auth_method:,
    aal_level_requested:,
    piv_cac_requested:,
    phishing_resistant_requested:
  )
    @user = user
    @mfa_context = MfaContext.new(user)
    @auth_method = auth_method
    @service_provider = service_provider
    @aal_level_requested = aal_level_requested
    @piv_cac_requested = piv_cac_requested
    @phishing_resistant_requested = phishing_resistant_requested
  end

  def user_needs_sp_auth_method_verification?
    # If the user needs to setup a new MFA method, return false so they go to
    # setup instead of verification
    return false if user_needs_sp_auth_method_setup?

    if piv_cac_required?
      auth_method.to_s != 'piv_cac'
    elsif phishing_resistant_required?
      !PHISHING_RESISTANT_METHODS.include?(auth_method.to_s)
    else
      false
    end
  end

  def user_needs_sp_auth_method_setup?
    return true if piv_cac_required? && !piv_cac_enabled?
    return true if phishing_resistant_required? && !phishing_resistant_enabled?
    false
  end

  def auth_method_confirms_to_sp_request?
    !user_needs_sp_auth_method_setup? && !user_needs_sp_auth_method_verification?
  end

  def phishing_resistant_required?
    if phishing_resistant_requested? || aal_requested?
      !!phishing_resistant_requested?
    else
      service_provider&.default_aal == 3
    end
  end

  def piv_cac_required?
    piv_cac_requested?
  end

  def allow_user_to_switch_method?
    return false if piv_cac_required?
    return true unless phishing_resistant_required?
    piv_cac_enabled? && webauthn_enabled?
  end

  def multiple_factors_enabled?
    mfa_context.enabled_mfa_methods_count > 1
  end

  private

  def phishing_resistant_enabled?
    piv_cac_enabled? || webauthn_enabled?
  end

  def aal_requested?
    @aal_level_requested.present?
  end

  def phishing_resistant_requested?
    @aal_level_requested == 3 ||
      @phishing_resistant_requested
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
