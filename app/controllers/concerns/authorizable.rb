module Authorizable
  def authorize_user
    return unless TwoFactorAuthentication::PhonePolicy.new(current_user).enabled?

    if user_fully_authenticated? && multiple_factors_enabled?
      redirect_to account_url
    elsif multiple_factors_enabled?
      redirect_to user_two_factor_authentication_url
    end
  end
end
