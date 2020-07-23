class AAL3Policy
  AAL3_METHODS = %w[webauthn piv_cac].freeze

  def initialize(session:, user: nil)
    @session = session
    @mfa_policy = MfaPolicy.new(user) if user
  end

  def aal3_required?
    aal3_requested? || aal3_configured?
  end

  def aal3_used?
    return false unless @session

    AAL3_METHODS.include?(@session[:auth_method])
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

  def multiple_aal3_configurations?
    @mfa_policy.aal3_configurations.count > 1
  end

  private

  def aal3_requested?
    return false unless @session

    sp_session = @session[:sp]
    sp_session && (sp_session[:aal_level_requested] == 3)
  end

  def aal3_configured?
    sp = sp_from_sp_session
    return false unless sp

    sp.aal == 3
  end

  def sp_from_sp_session
    return unless @session

    sp_session = @session[:sp]
    return unless sp_session

    sp = ServiceProvider.from_issuer(sp_session[:issuer])
    sp if sp.is_a? ServiceProvider
  end
end
