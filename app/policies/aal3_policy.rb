class AAL3Policy
  def initialize(user)
    @user = MfaContext.new(user)
  end

  def aal3_required?
    true
  end

  def enabled_aal3_auth_methods
    auth_methods = []
    auth_methods << user.webauthn_configurations if user.webauthn_configurations.any?
    auth_methods << user.piv_cac_configurations if user.piv_cac_configurations.any?
    auth_methods || AAL3Policy.none
  end
end
