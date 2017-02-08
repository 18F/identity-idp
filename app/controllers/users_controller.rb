class UsersController < ApplicationController
  def destroy
    return unless current_user.destroy!

    flash[:success] = t('loa1.cancel.success')
    redirect_to root_path
  end
end
