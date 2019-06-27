class SignUpProgressPolicy
  def initialize(user, fully_authenticated)
    @user = user
    @fully_authenticated = fully_authenticated
  end

  def sign_up_progress_visible?
    user_is_on_first_step? || user_is_on_second_step?
  end

  private

  def user_is_on_first_step?
    !@fully_authenticated && enabled_mfa_methods_count.zero?
  end

  def user_is_on_second_step?
    @fully_authenticated && enabled_mfa_methods_count == 1
  end

  def enabled_mfa_methods_count
    @enabled_mfa_methods_count ||= MfaContext.new(@user).enabled_mfa_methods_count
  end
end
