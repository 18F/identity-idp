class MfaConfirmationController < ApplicationController
  before_action :confirm_two_factor_authenticated

  def create
    if current_user.valid_password?(password)
      redirect_to user_two_factor_authentication_path(reauthn: true)
    else
      flash[:error] = t('errors.confirm_password_incorrect')
      redirect_to user_password_confirm_path
    end
  end

  private

  def password
    params.require(:user)[:password]
  end
end
