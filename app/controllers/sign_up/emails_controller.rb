module SignUp
  class EmailsController < ApplicationController
    def show
      if session[:email].blank?
        redirect_to sign_up_email_url
      else
        @resend_confirmation = params[:resend].present?

        email = session.delete(:email)
        @resend_email_confirmation_form = ResendEmailConfirmationForm.new(email:)

        render :show, locals: { email: }
      end
    end
  end
end
