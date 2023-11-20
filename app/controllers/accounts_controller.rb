class AccountsController < ApplicationController
  include RememberDeviceConcern
  before_action :confirm_two_factor_authenticated
  before_action :confirm_user_is_not_suspended

  layout 'account_side_nav'

  def show
    analytics.account_visit
    session[:account_redirect_path] = account_path
    cacher = Pii::Cacher.new(current_user, user_session)
    profile_id = current_user.active_profile&.id || current_user.pending_profile&.id
    @presenter = AccountShowPresenter.new(
      decrypted_pii: cacher.fetch(profile_id),
      personal_key: flash[:personal_key],
      sp_session_request_url: sp_session_request_url_with_updated_params,
      sp_name: decorated_sp_session.sp_name,
      user: current_user,
      locked_for_session: pii_locked_for_session?(current_user),
    )
  end

  # This action is used to re-authenticate when PII on the account page is locked on `show` action
  # This allows users to view their PII after reauthenticating their MFA.

  def reauthentication
    user_session[:stored_location] = account_url
    user_session[:context] = 'reauthentication'

    redirect_to login_two_factor_options_path
  end

  private

  def confirm_user_is_not_suspended
    redirect_to user_please_call_url if current_user.suspended?
  end
end
