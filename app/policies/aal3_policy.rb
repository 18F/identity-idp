class AAL3Policy
  def initialize(session:, user: nil)
    @session = session
    @mfa_policy = MfaPolicy.new(user) if user
  end

  def aal3_required?
    return false unless @session

    sp_session = @session[:sp]
    sp_session && (sp_session[:aal_level_requested] == 3)
  end

  def aal3_used?
    return false unless @session

    %w[webauthn piv_cac].include?(@session[:auth_method])
  end

  def aal3_configured_but_not_used?
    aal3_required? &&
      @mfa_policy&.aal3_mfa_enabled? &&
      !aal3_used?
  end
end
