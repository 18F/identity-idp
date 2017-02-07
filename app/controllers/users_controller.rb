class UsersController < ApplicationController
  before_action :confirm_two_factor_authenticated

  def destroy
    return unless current_user.destroy!

    flash.now[:success] = t('loa1.cancel.success')
    redirect_to root_path
  end
end
