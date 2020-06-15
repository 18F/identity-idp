class AAL3Policy
  def initialize(user, sp_session, session)
    @user = MfaContext.new(user)
    @sp_session = sp_session
    @session = session
  end

  def aal3_required?
    @sp_session[:aal_level_requested] == 3
  end

  def aal3_used?
    %w[webauthn piv_cac].include?(@session[:auth_method])
  end
end
