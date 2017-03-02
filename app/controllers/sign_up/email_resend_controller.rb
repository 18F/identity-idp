module SignUp
  class EmailResendController < ApplicationController
    include UnconfirmedUserConcern

    def new
      @user = User.new
      @resend_email_confirmation_form = ResendEmailConfirmationForm.new
    end

    def create
      @resend_email_confirmation_form = ResendEmailConfirmationForm.new(email_from_params)
      result = @resend_email_confirmation_form.submit

      analytics.track_event(Analytics::EMAIL_CONFIRMATION_RESEND, result)

      if result[:success]
        handle_valid_email
      else
        render :new
      end
    end

    private

    def email_from_params
      params[:resend_email_confirmation_form][:email]
    end

    def handle_valid_email
      User.send_confirmation_instructions(email: form_email)
      session[:email] = form_email
      redirect_to sign_up_verify_email_path
    end

    def form_email
      @resend_email_confirmation_form.email
    end
  end
end
