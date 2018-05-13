class ReactivateAccountController < ApplicationController
  include AccountReactivationConcern

  before_action :confirm_two_factor_authenticated
  before_action :confirm_password_reset_profile

  def index; end

  def update
    reactivate_account_session.suspend
    redirect_to idv_url
  end
end
