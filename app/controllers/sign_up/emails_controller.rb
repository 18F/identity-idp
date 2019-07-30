module SignUp
  class EmailsController < ApplicationController
    def show
      if session[:email].blank?
        redirect_to sign_up_email_url
      else
        @resend_confirmation = params[:resend].present?

        email = session.delete(:email)
        @resend_email_confirmation_form = ResendEmailConfirmationForm.new(
          email: email, request_id: params[:request_id],
        )

        render :show, locals: { email: email }
      end
    end
  end
end
