module Authorizable
  def authorize_user
    two_factor_method_manager = TwoFactorAuthentication::MethodManager.new(current_user)

    return unless two_factor_method_manager.two_factor_enabled?(%i[sms voice])

    if user_fully_authenticated?
      redirect_to account_url
    elsif two_factor_method_manager.two_factor_enabled?
      redirect_to user_two_factor_authentication_url
    end
  end
end
