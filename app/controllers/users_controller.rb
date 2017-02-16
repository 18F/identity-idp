class UsersController < ApplicationController
  def destroy
    destroy_user
    flash[:success] = t('sign_up.cancel.success')
    redirect_to root_path
  end

  private

  def destroy_user
    user = current_user || User.where(confirmation_token: session[:user_confirmation_token]).take
    user && user.destroy!
  end
end
