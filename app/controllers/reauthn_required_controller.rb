class ReauthnRequiredController < ApplicationController
  before_action :confirm_recently_authenticated

  def confirm_recently_authenticated
    @reauthn = reauthn?
    return unless user_signed_in?
    return if recently_authenticated?
    store_location_for(:user, request.url)
    redirect_to user_password_confirm_url
  end

  def recently_authenticated?
    return false unless user_session.present?
    authn_at = user_session[:authn_at]
    return false unless authn_at.present?
    authn_at > Time.zone.now - Figaro.env.reauthn_window.to_i
  end
end
