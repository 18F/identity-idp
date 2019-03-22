class AccountRecoverySetupController < ApplicationController
  include AccountRecoverable
  include UserAuthenticator

  before_action :confirm_two_factor_authenticated

  def index
    return redirect_to account_url if MfaPolicy.new(current_user).multiple_factors_enabled?
    @two_factor_options_form = TwoFactorOptionsForm.new(current_user)
    @presenter = account_recovery_options_presenter
  end

  private

  def account_recovery_options_presenter
    AccountRecoveryOptionsPresenter.new(current_user, current_sp)
  end
end
