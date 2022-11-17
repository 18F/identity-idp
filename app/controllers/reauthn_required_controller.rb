class ReauthnRequiredController < ApplicationController
  before_action :confirm_recently_authenticated

  private

  def confirm_recently_authenticated
    @reauthn = reauthn?
    return unless user_signed_in?
    return if recently_authenticated?

    prompt_for_current_password
  end

  def recently_authenticated?
    return false if user_session.blank?
    authn_at = user_session[:authn_at]
    return false if authn_at.blank?
    authn_at > Time.zone.now - IdentityConfig.store.reauthn_window
  end

  def prompt_for_current_password
    store_location(request.url)
    user_session[:context] = 'reauthentication'
    user_session[:factor_to_change] = factor_from_controller_name
    user_session[:current_password_required] = true
    redirect_to user_password_confirm_url
  end

  def factor_from_controller_name
    {
      # see LG-5701, translate these
      'emails' => 'email',
      'passwords' => 'password',
      'phones' => 'phone',
      'personal_keys' => 'personal key',
    }[controller_name]
  end

  def store_location(url)
    user_session[:stored_location] = url
  end
end
