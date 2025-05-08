# frozen_string_literal: true

module Idv
  class ForgotPasswordController < ApplicationController
    include Idv::AvailabilityConcern
    include IdvSessionConcern

    before_action :confirm_two_factor_authenticated
    before_action :confirm_idv_needed

    def new
      analytics.idv_forgot_password
    end

    def update
      analytics.idv_forgot_password_confirmed
      request_id = sp_session[:request_id]
      email = current_user.last_sign_in_email_address.email
      reset_password(email, request_id)
    end

    private

    def reset_password(email, request_id)
      sign_out
      RequestPasswordReset.new(
        email:,
        request_id:,
        analytics:,
        attempts_api_tracker:,
      ).perform
      # The user/email is always found so...
      session[:email] = email
      redirect_to forgot_password_url(request_id: request_id)
    end
  end
end
