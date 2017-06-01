class ResetPasswordController < ApplicationController
  def index; end

  def update
    if personal_key == 'true'
      flash[:notice] = t('notices.password_reset')
      session[:personal_key] = true
    else
      session[:personal_key] = false
    end

    redirect_to new_user_password_path
  end

  private

  def personal_key
    params.require(:personal_key)
  end
end
