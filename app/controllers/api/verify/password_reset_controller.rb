module Api
  module Verify
    class PasswordResetController < Api::BaseController
      def create
        analytics.idv_forgot_password_confirmed
        request_id = sp_session[:request_id]
        email = current_user.email
        reset_password(email, request_id)

        render json: { redirect_url: forgot_password_url(request_id: request_id) },
               status: :accepted
      end

      private

      def reset_password(email, request_id)
        sign_out
        RequestPasswordReset.new(email: email, request_id: request_id, analytics: analytics).perform
        session[:email] = email
      end
    end
  end
end
