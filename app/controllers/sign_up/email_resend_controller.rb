module SignUp
  class EmailResendController < ApplicationController
    include UnconfirmedUserConcern

    def new
      @user = User.new
      @resend_email_confirmation_form = ResendEmailConfirmationForm.new
    end

    def create
      @resend_email_confirmation_form = ResendEmailConfirmationForm.new(permitted_params)
      result = @resend_email_confirmation_form.submit

      analytics.track_event(Analytics::USER_REGISTRATION_EMAIL_CONFIRMATION_RESEND, result.to_h)

      if result.success?
        handle_valid_email
      else
        render :new
      end
    end

    private

    def permitted_params
      params.require(:resend_email_confirmation_form).permit(:email, :request_id)
    end

    def handle_valid_email
      session[:email] = form_email
      redirect_to sign_up_verify_email_url
    end

    def form_email
      @resend_email_confirmation_form.email
    end
  end
end
