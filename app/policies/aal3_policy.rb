class AAL3Policy
  def initialize(user, session)
    @user = MfaContext.new(user)
    @session = session
  end

  def aal3_required?
    @session[:aal3]
  end

  def aal3_requirement_met?
    # If AAL3 is required, check if the user has it. Otherwise, requirement met
    !aal3_required? || aal3_methods_enabled?
  end

  def aal3_methods_enabled?
    @user.webauthn_configurations.any? || @user.piv_cac_configurations.any?
  end


end
