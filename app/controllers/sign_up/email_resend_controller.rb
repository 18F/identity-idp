# frozen_string_literal: true

module SignUp
  class EmailResendController < ApplicationController
    def new
      @user = User.new
      @resend_email_confirmation_form = ResendEmailConfirmationForm.new
    end
  end
end
