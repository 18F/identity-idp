module SignUp
  class EmailResendController < ApplicationController
    include UnconfirmedUserConcern

    def new
      @user = User.new
      @resend_email_confirmation_form = ResendEmailConfirmationForm.new
    end

    def create
      @resend_email_confirmation_form = ResendEmailConfirmationForm.new(downcased_email)
      result = @resend_email_confirmation_form.submit

      analytics.track_event(Analytics::EMAIL_CONFIRMATION_RESEND, result)

      if result[:success]
        handle_valid_email
      else
        render :new
      end
    end

    private

    def downcased_email
      params[:resend_email_confirmation_form][:email].downcase
    end

    def handle_valid_email
      User.send_confirmation_instructions(email: downcased_email)
      session[:email] = downcased_email
      resend_confirmation = params[:resend_email_confirmation_form][:resend]
      redirect_to sign_up_verify_email_path(resend: resend_confirmation)
    end
  end
end
