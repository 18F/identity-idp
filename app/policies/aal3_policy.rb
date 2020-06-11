class AAL3Policy
  def initialize(user, sp_session, session)
    @user = MfaContext.new(user)
    @sp_session = sp_session
    @session = session
  end

  def aal3_required?
    @sp_session[:aal3]
  end

  def aal3_used?
    %w[webauthn piv_cac].include?(@session[:auth_method])
  end

  def aal3_methods_enabled?
    @user.webauthn_configurations.any? || @user.piv_cac_configurations.any?
  end


end
