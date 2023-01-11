module SignUp
  class EmailResendController < ApplicationController
    def new
      @user = User.new
      @resend_email_confirmation_form = ResendEmailConfirmationForm.new(
        request_id: params[:request_id],
      )
    end
  end
end
