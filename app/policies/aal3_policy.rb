class AAL3Policy
  def initialize(user)
    @user = MfaContext.new(user)
  end

  def aal3_required?
    false
  end

end
