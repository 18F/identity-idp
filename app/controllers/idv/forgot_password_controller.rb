module Idv
  class ForgotPasswordController < ApplicationController
    include IdvSession

    before_action :confirm_two_factor_authenticated
    before_action :confirm_idv_needed

    def new
      analytics.track_event(Analytics::IDV_FORGOT_PASSWORD)
      @presenter = ForgotPasswordPresenter.new(view_context: view_context)
    end

    def update
      analytics.track_event(Analytics::IDV_FORGOT_PASSWORD_CONFIRMED)
      request_id = sp_session[:request_id]
      email = current_user.email
      reset_password(email, request_id)
    end

    private

    def reset_password(email, request_id)
      sign_out
      RequestPasswordReset.new(email, request_id).perform
      # The user/email is always found so...
      session[:email] = email
      redirect_to forgot_password_url(request_id: request_id)
    end
  end
end
