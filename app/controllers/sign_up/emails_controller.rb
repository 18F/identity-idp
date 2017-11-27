module SignUp
  class EmailsController < ApplicationController
    def show
      if session[:email].blank?
        redirect_to sign_up_email_path
      else
        @resend_confirmation = params[:resend].present?

        email = session.delete(:email)
        @register_user_email_form = RegisterUserEmailForm.new
        @register_user_email_form.user.email = email

        render :show, locals: { email: email }
      end
    end
  end
end
