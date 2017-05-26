class ResetPasswordController < ApplicationController
  def index; end

  def update
    flash[:notice] = 'Great! You have you personal key. We\'ll ask for that in a minute.'

    redirect_to new_user_password_path
  end
end
