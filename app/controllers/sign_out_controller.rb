class SignOutController < ApplicationController
  include FullyAuthenticatable

  def destroy
    analytics.logout_initiated(method: 'cancel link')
    irs_attempts_api_tracker.logout_initiated(
      success: true,
    )
    url_after_cancellation = decorated_session.cancel_link_url
    sign_out
    flash[:success] = t('devise.sessions.signed_out')
    redirect_to(url_after_cancellation, allow_other_host: true)
    delete_branded_experience
  end
end
