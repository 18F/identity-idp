class AccountsController < ApplicationController
  include RememberDeviceConcern
  before_action :confirm_two_factor_authenticated
  before_action :confirm_user_is_not_suspended

  layout 'account_side_nav'

  def show
    analytics.account_visit
    session[:account_redirect_path] = account_path
    cacher = Pii::Cacher.new(current_user, user_session)
    @presenter = AccountShowPresenter.new(
      decrypted_pii: cacher.fetch(current_user.active_or_pending_profile&.id),
      sp_session_request_url: sp_session_request_url_with_updated_params,
      sp_name: decorated_sp_session.sp_name,
      user: current_user,
      locked_for_session: pii_locked_for_session?(current_user),
    )
  end

  def reauthentication
    # This route sends a user through reauthentication and returns them to the account page, since
    # some actions within the account dashboard require a fresh reauthentication (e.g. managing an
    # MFA method or viewing verified profile information).
    user_session[:stored_location] = account_url(params.permit(:manage_authenticator))
    user_session[:context] = 'reauthentication'

    redirect_to login_two_factor_options_path
  end

  private

  def confirm_user_is_not_suspended
    redirect_to user_please_call_url if current_user.suspended?
  end
end
