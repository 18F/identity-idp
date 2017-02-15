class UsersController < ApplicationController
  def destroy
    return unless current_user.destroy!

    flash[:success] = t('sign_up.cancel.success')
    redirect_to root_path
  end
end
