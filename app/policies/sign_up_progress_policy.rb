class SignUpProgressPolicy
  def initialize(user, fully_authenticated)
    @user = user
    @fully_authenticated = fully_authenticated
  end

  def sign_up_progress_visible?
    if !@fully_authenticated || (@fully_authenticated && !sufficient_factors_enabled?)
      true
    else
      false
    end
  end

  private

  def sufficient_factors_enabled?
    MfaPolicy.new(@user).sufficient_factors_enabled?
  end
end
