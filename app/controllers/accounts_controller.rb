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
      decorated_user: current_user.decorate,
      locked_for_session: pii_locked_for_session?(current_user),
      account_reset_requested: current_user&.account_reset_request
    )
  end
end
