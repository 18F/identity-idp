class UsersController < ApplicationController
  def destroy
    current_user && curent_user.destroy!

    flash[:success] = t('sign_up.cancel.success')
    redirect_to root_path
  end
end
