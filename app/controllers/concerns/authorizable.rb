module Authorizable
  def authorize_user
    return unless TwoFactorAuthentication::PhonePolicy.new(current_user).enabled?

    if user_fully_authenticated?
      redirect_to account_url
    elsif MfaPolicy.new(current_user).two_factor_enabled?
      redirect_to user_two_factor_authentication_url
    end
  end
end
