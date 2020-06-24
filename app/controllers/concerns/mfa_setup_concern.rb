module MfaSetupConcern
  extend ActiveSupport::Concern

  def confirm_user_authenticated_for_2fa_setup
    puts "#{'~'*10} MfaSetupConcern#confirm_user_authenticated_for_2fa_setup"
    # binding.pry
    authenticate_user!(force: true)
    return if user_fully_authenticated?
    return unless MfaPolicy.new(current_user).two_factor_enabled?
    redirect_to user_two_factor_authentication_url
  end
end
