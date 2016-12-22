class ForgotPasswordController < ApplicationController
  def show
    if session[:email].blank?
      redirect_to new_user_password_path
    else
      @resend_confirmation = params[:resend].present?
      @email = session.delete(:email)

      @password_reset_email_form = PasswordResetEmailForm.new(@email)
    end
  end
end
