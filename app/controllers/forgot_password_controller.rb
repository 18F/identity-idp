class ForgotPasswordController < ApplicationController
  def show
    if session[:email].blank?
      redirect_to new_user_password_url
    else
      @view_model = ForgotPasswordShow.new(resend: params[:resend], session: session)
    end
  end
end
