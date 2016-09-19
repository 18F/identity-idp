require 'feature_management'

module Devise
  class TwoFactorAuthenticationController < DeviseController
    include TwoFactorAuthenticatable

    def show
      if current_user.totp_enabled?
        redirect_to login_two_factor_authenticator_path
      else
        @phone_number = user_decorator.masked_two_factor_phone_number
        @otp_delivery_selection_form = OtpDeliverySelectionForm.new
      end
    end

    def send_code
      @otp_delivery_selection_form = OtpDeliverySelectionForm.new

      result = @otp_delivery_selection_form.submit(delivery_params)

      analytics.track_event(:otp_delivery_selection, result)

      if result[:success?]
        handle_valid_delivery_method(delivery_params[:otp_method])
      else
        redirect_to user_two_factor_authentication_path
      end
    end

    private

    def handle_valid_delivery_method(method)
      send_user_otp(method)

      flash[:success] = t("notices.send_code.#{method}")
      redirect_to login_two_factor_path(delivery_method: method)
    end

    def send_user_otp(method)
      current_user.create_direct_otp

      job = "#{method.capitalize}SenderOtpJob".constantize

      job.perform_later(current_user.direct_otp, current_user.phone)
    end

    def delivery_params
      params.require(:otp_delivery_selection_form).permit(:otp_method, :resend)
    end
  end
end
