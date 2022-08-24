module Api
  module Verify
    class PasswordResetController < BaseController
      self.required_step = 'password_confirm'

      def create
        analytics.idv_forgot_password_confirmed
        request_id = sp_session[:request_id]
        email = current_user.confirmed_email_addresses.first.email
        reset_password(email, request_id)

        render json: { redirect_url: forgot_password_url(request_id: request_id) },
               status: :accepted
      end

      private

      def reset_password(email, request_id)
        sign_out
        RequestPasswordReset.new(
          email: email,
          request_id: request_id,
          analytics: analytics,
          irs_attempts_api_tracker: irs_attempts_api_tracker,
        ).perform
        session[:email] = email
      end
    end
  end
end
