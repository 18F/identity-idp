module MfaSetupConcern
  extend ActiveSupport::Concern

  def confirm_user_authenticated_for_2fa_setup
    authenticate_user!(force: true)
    return if user_fully_authenticated?
    return unless MfaPolicy.new(current_user).sufficient_factors_enabled?(session[:signing_up])
    redirect_to user_two_factor_authentication_url
  end
end
