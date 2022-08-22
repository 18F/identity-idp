module Idv
  class ForgotPasswordController < ApplicationController
    include IdvSession

    before_action :confirm_two_factor_authenticated
    before_action :confirm_idv_needed

    def new
      analytics.idv_forgot_password
    end

    def update
      analytics.idv_forgot_password_confirmed
      request_id = sp_session[:request_id]
      email = current_user.confirmed_email_addresses.first.email
      reset_password(email, request_id)
    end

    private

    def reset_password(email, request_id)
      sign_out
      RequestPasswordReset.new(
        email: email, request_id: request_id, analytics: analytics,
        irs_attempts_api_tracker: irs_attempts_api_tracker
      ).perform
      # The user/email is always found so...
      session[:email] = email
      redirect_to forgot_password_url(request_id: request_id)
    end
  end
end
