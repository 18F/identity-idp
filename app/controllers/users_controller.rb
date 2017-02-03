class UsersController < ApplicationController
  def destroy
    return unless current_user

    if current_user.destroy!
      flash[:now] = t('users.delete')
      redirect_to root_path
    end
  end
end
