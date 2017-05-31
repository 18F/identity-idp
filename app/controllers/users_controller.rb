class UsersController < ApplicationController
  def destroy
    destroy_user
    flash[:success] = t('sign_up.cancel.success')
    redirect_to root_path
  end

  private

  def destroy_user
    user = current_user || User.find_by(confirmation_token: session[:user_confirmation_token])
    user && user.destroy!
    sign_out if user
  end
end
