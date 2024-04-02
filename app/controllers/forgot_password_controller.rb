# frozen_string_literal: true

class ForgotPasswordController < ApplicationController
  def show
    if session[:email].blank?
      redirect_to new_user_password_url
    else
      @email = session.delete(:email)
      @password_reset_email_form = PasswordResetEmailForm.new(@email)
      @resend = params[:resend]
    end
  end
end
