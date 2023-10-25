# frozen_string_literal: true

module ReauthenticationRequiredConcern
  include MfaSetupConcern
  include TwoFactorAuthenticatableMethods

  def confirm_recently_authenticated_2fa
    return if !user_fully_authenticated? || auth_methods_session.recently_authenticated_2fa?

    analytics.user_2fa_reauthentication_required(
      auth_method: auth_methods_session.last_auth_event&.[](:auth_method),
      authenticated_at: auth_methods_session.last_auth_event&.[](:at),
    )

    prompt_for_second_factor
  end

  private

  def prompt_for_second_factor
    store_location(request.url)
    user_session[:context] = 'reauthentication'

    redirect_to login_two_factor_options_path
  end

  def store_location(url)
    user_session[:stored_location] = url
  end
end
