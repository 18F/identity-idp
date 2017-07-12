module Users
  class TwoFactorAuthenticationController < ApplicationController
    include TwoFactorAuthenticatable
    skip_before_action :handle_two_factor_authentication

    def show
      if current_user.totp_enabled?
        redirect_to login_two_factor_authenticator_path
      elsif current_user.two_factor_enabled?
        handle_valid_otp_delivery_preference(current_user.otp_delivery_preference)
      else
        redirect_to phone_setup_path
      end
    end

    def send_code
      @otp_delivery_selection_form = OtpDeliverySelectionForm.new(current_user, phone_to_deliver_to)

      result = @otp_delivery_selection_form.submit(delivery_params)

      track_otp_delivery_selection_event(result)

      if result.success?
        handle_valid_otp_delivery_preference(user_selected_otp_delivery_preference)
      else
        redirect_to user_two_factor_authentication_path(reauthn: reauthn?)
      end
    end

    private

    def reauthn_param
      otp_form = params.permit(otp_delivery_selection_form: [:reauthn])
      super || otp_form.dig(:otp_delivery_selection_form, :reauthn)
    end

    def handle_valid_otp_delivery_preference(method)
      otp_rate_limiter.reset_count_and_otp_last_sent_at if decorated_user.no_longer_locked_out?

      if otp_rate_limiter.exceeded_otp_send_limit?
        otp_rate_limiter.lock_out_user

        return handle_too_many_otp_sends
      end

      send_user_otp(method)
      session[:code_sent] = 'true'
      redirect_to login_two_factor_path(otp_delivery_preference: method, reauthn: reauthn?)
    end

    def send_user_otp(method)
      otp_rate_limiter.increment
      current_user.create_direct_otp

      job = "#{method.capitalize}OtpSenderJob".constantize

      job.perform_later(
        code: current_user.direct_otp,
        phone: phone_to_deliver_to,
        otp_created_at: current_user.direct_otp_sent_at.to_s
      )
    end

    def track_otp_delivery_selection_event(result)
      attributes = result.to_h.merge(context: context)
      analytics.track_event(Analytics::OTP_DELIVERY_SELECTION, attributes)
    end

    def user_selected_otp_delivery_preference
      delivery_params[:otp_delivery_preference]
    end

    def delivery_params
      params.require(:otp_delivery_selection_form).permit(:otp_delivery_preference, :resend)
    end

    def phone_to_deliver_to
      return current_user.phone if authentication_context?

      user_session[:unconfirmed_phone]
    end

    def otp_rate_limiter
      @_otp_rate_limited ||= OtpRateLimiter.new(phone: phone_to_deliver_to, user: current_user)
    end
  end
end
