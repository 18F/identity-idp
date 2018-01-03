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
    authn_at > Time.zone.now - Figaro.env.reauthn_window.to_i
  end

  def prompt_for_current_password
    store_location(request.url)
    user_session[:context] = 'reauthentication'
    user_session[:factor_to_change] = factor_from_request_path(request.path)
    user_session[:current_password_required] = true
    redirect_to user_password_confirm_url
  end

  def factor_from_request_path(path)
    path.split('/')[-1]
  end

  def store_location(url)
    user_session[:stored_location] = url
  end
end
