module ReauthenticationRequiredConcern
  include MfaSetupConcern
  include TwoFactorAuthenticatableMethods

  def confirm_recently_authenticated_2fa
    return if !user_fully_authenticated? || recently_authenticated_2fa?

    analytics.user_2fa_reauthentication_required(
      auth_method: auth_methods_session.last_auth_event&.[](:auth_method),
      authenticated_at: auth_methods_session.last_auth_event&.[](:at),
    )

    prompt_for_second_factor
  end

  def recently_authenticated_2fa?
    user_fully_authenticated? && auth_methods_session.recently_authenticated_2fa?
  end

  private

  def prompt_for_second_factor
    store_location(request.path)
    user_session[:context] = 'reauthentication'

    redirect_to login_two_factor_options_path
  end

  def store_location(url)
    if request.method != :get
      user_session[:stored_location] = account_path
    else
      user_session[:stored_location] = url
    end
  end
end
