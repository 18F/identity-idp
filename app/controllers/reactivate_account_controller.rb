class ReactivateAccountController < ApplicationController
  include AccountReactivationConcern

  before_action :confirm_two_factor_authenticated
  before_action :confirm_password_reset_profile

  def index
    analytics.reactivate_account_visit
    @personal_key_generated_at = current_user.personal_key_generated_at
  end

  def update
    analytics.reactivate_account_submit
    reactivate_account_session.suspend
    redirect_to idv_url
  end
end
