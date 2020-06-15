class AAL3Policy
  def initialize(session)
    @session = session
  end

  def aal3_required?
    sp_session = @session[:sp]
    sp_session && (sp_session[:aal_level_requested] == 3)
  end

  def aal3_used?
    %w[webauthn piv_cac].include?(@session[:auth_method])
  end
end
