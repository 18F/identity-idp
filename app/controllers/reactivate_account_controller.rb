class ReactivateAccountController < ApplicationController
  include AccountReactivationConcern
  include RememberDeviceConcern

  before_action :confirm_two_factor_authenticated
  before_action :confirm_password_reset_profile

  def index
    @presenter = AccountShowPresenter.new(
      decrypted_pii: nil,
      personal_key: nil,
      sp_session_request_url: sp_session_request_url_with_updated_params,
      sp_name: decorated_session.sp_name,
      decorated_user: current_user.decorate,
      locked_for_session: pii_locked_for_session?(current_user),
    )
  end

  def update
    reactivate_account_session.suspend
    redirect_to idv_url
  end
end
