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
    user_session[:factor_to_change], user_session[:no_factor_message] =
      factor_or_message_from_path(request.path)
    user_session[:current_password_required] = true
    redirect_to user_password_confirm_url
  end

  def factor_or_message_from_path(path)
    factor = path.split('/')[-1]
    message = nil
    if factor == 'delete'
      factor = nil
      message = I18n.t('help_text.no_factor.delete_account')
    end
    [factor, message]
  end

  def store_location(url)
    user_session[:stored_location] = url
  end
end
