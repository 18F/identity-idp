# frozen_string_literal: true

module SignUp
  class EmailsController < ApplicationController
    def show
      if session[:email].blank?
        redirect_to sign_up_email_url
      else
        @resend_confirmation = params[:resend].present?

        email = session.delete(:email)
        terms_accepted = session.delete(:terms_accepted)
        @resend_email_confirmation_form = ResendEmailConfirmationForm.new(email:, terms_accepted:)

        render :show, locals: { email: email }
      end
    end
  end
end
