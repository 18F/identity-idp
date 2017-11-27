class SignOutController < ApplicationController
  include FullyAuthenticatable

  skip_before_action :handle_two_factor_authentication

  def destroy
    url_after_cancellation = decorated_session.cancel_link_url
    sign_out
    flash[:success] = t('devise.sessions.signed_out')
    redirect_to url_after_cancellation
    delete_branded_experience
  end
end
