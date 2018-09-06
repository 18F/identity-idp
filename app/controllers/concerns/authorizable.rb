module Authorizable
  def authorize_user
    mfa = current_user.mfa
    return unless mfa.phone_configurations.any?(&:mfa_enabled?)

    if user_fully_authenticated?
      redirect_to account_url
    elsif mfa.two_factor_enabled?
      redirect_to user_two_factor_authentication_url
    end
  end
end
