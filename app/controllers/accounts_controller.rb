class AccountsController < ApplicationController
  include RememberDeviceConcern
  before_action :confirm_two_factor_authenticated

  layout 'account_side_nav'

  def show
    analytics.account_visit
    session[:account_redirect_path] = account_path
    cacher = Pii::Cacher.new(current_user, user_session)
    @presenter = AccountShowPresenter.new(
      decrypted_pii: cacher.fetch,
      personal_key: flash[:personal_key],
      sp_session_request_url: sp_session_request_url_with_updated_params,
      sp_name: decorated_session.sp_name,
      user: current_user,
      locked_for_session: pii_locked_for_session?(current_user),
    )
    @use_reauthentication_route = FeatureManagement.use_reauthentication_route?
  end

  # This action is used to re-authenticate when PII on the account page is locked on `show` action
  # This allows users to view their PII after reauthenticating their MFA.

  def reauthentication
    user_session[:stored_location] = account_url
    user_session[:context] = 'reauthentication'

    redirect_to login_two_factor_options_path(reauthn: true)
  end
end
