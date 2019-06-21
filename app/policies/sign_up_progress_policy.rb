class SignUpProgressPolicy
  def initialize(user, fully_authenticated, sufficient_factors_enabled)
    @user = user
    @fully_authenticated = fully_authenticated
    @sufficient_factors_enabled = sufficient_factors_enabled
  end

  def sign_up_progress_visible?
    if !@fully_authenticated || (@fully_authenticated && !@sufficient_factors_enabled)
      true
    else
      false
    end
  end
end
