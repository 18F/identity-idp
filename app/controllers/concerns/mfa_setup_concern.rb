module MfaSetupConcern
  extend ActiveSupport::Concern

  def confirm_user_authenticated_for_2fa_setup
    authenticate_user!(force: true)
    return if user_fully_authenticated?
    return unless MfaPolicy.new(current_user, session).two_factor_enabled?
    return if hspd12_policy.piv_cac_setup_required?
    redirect_to user_two_factor_authentication_url
  end
end
