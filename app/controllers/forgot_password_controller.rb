class ForgotPasswordController < ApplicationController
  def show
    if session[:email].blank?
      redirect_to new_user_password_path
    else
      @view_model = ForgotPasswordShow.new(params: params, session: session)
    end
  end
end
