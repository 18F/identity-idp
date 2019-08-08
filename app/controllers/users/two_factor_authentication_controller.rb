module Users
  # rubocop:disable Metrics/ClassLength
  class TwoFactorAuthenticationController < ApplicationController
    include TwoFactorAuthenticatable

    before_action :check_remember_device_preference

    def show
      non_phone_redirect || phone_redirect || backup_code_redirect || redirect_on_nothing_enabled
    rescue Telephony::TelephonyError => telephony_error
      invalid_phone_number(telephony_error, action: 'show')
    end

    def send_code
      result = otp_delivery_selection_form.submit(delivery_params)
      analytics.track_event(Analytics::OTP_DELIVERY_SELECTION, result.to_h)
      if result.success?
        handle_valid_otp_params(user_select_delivery_preference, user_selected_default_number)
        update_otp_delivery_preference_if_needed
      else
        handle_invalid_otp_delivery_preference(result)
      end
    rescue Telephony::TelephonyError => telephony_error
      invalid_phone_number(telephony_error, action: 'send_code')
    end

    private

    def phone_enabled?
      phone_configuration&.mfa_enabled?
    end

    def phone_configuration
      MfaContext.new(current_user).phone_configuration(user_session[:phone_id])
    end

    def validate_otp_delivery_preference_and_send_code
      result = otp_delivery_selection_form.submit(otp_delivery_preference: delivery_preference)
      analytics.track_event(Analytics::OTP_DELIVERY_SELECTION, result.to_h)

      if result.success?
        handle_valid_otp_params(delivery_preference)
      else
        handle_valid_otp_params('sms')
        flash[:error] = result.errors[:phone].first
      end
    end

    def delivery_preference
      phone_configuration&.delivery_preference || current_user.otp_delivery_preference
    end

    def update_otp_delivery_preference_if_needed
      return unless user_signed_in?
      OtpPreferenceUpdater.new(
        user: current_user,
        preference: delivery_params[:otp_delivery_preference],
        phone_id: user_session[:phone_id],
      ).call
    end

    def handle_invalid_otp_delivery_preference(result)
      flash[:error] = result.errors[:phone].first
      redirect_to login_two_factor_url(otp_delivery_preference: delivery_preference)
    end

    def invalid_phone_number(telephony_error, action:)
      capture_analytics_for_exception(telephony_error)

      if action == 'show'
        redirect_to_otp_verification_with_error
      else
        flash[:error] = telephony_error.friendly_message
        redirect_back(fallback_location: account_url)
      end
    end

    def redirect_to_otp_verification_with_error
      flash[:error] = t('errors.messages.phone_unsupported')
      redirect_to login_two_factor_url(
        otp_delivery_preference: phone_configuration.delivery_preference,
        reauthn: reauthn?,
      )
    end

    def capture_analytics_for_exception(telephony_error)
      attributes = {
        error: telephony_error.class.to_s,
        message: telephony_error.message,
        context: context,
        country: parsed_phone.country,
      }
      analytics.track_event(Analytics::TWILIO_PHONE_VALIDATION_FAILED, attributes)
    end

    def parsed_phone
      @parsed_phone ||= Phonelib.parse(phone_to_deliver_to)
    end

    def error_message(code)
      twilio_errors.fetch(code, t('errors.messages.otp_failed'))
    end

    def twilio_errors
      TwilioErrors::REST_ERRORS.merge(TwilioErrors::VERIFY_ERRORS)
    end

    def otp_delivery_selection_form
      @otp_delivery_selection_form ||= OtpDeliverySelectionForm.new(
        current_user, phone_to_deliver_to, context
      )
    end

    def reauthn_param
      otp_form = params.permit(otp_delivery_selection_form: [:reauthn])
      super || otp_form.dig(:otp_delivery_selection_form, :reauthn)
    end

    def handle_valid_otp_params(method, default = nil)
      otp_rate_limiter.reset_count_and_otp_last_sent_at if decorated_user.no_longer_locked_out?

      return handle_too_many_otp_sends if exceeded_otp_send_limit?
      otp_rate_limiter.increment
      return handle_too_many_otp_sends if exceeded_otp_send_limit?

      send_user_otp(method)
      redirect_to login_two_factor_url(otp_delivery_preference: method,
                                       otp_make_default_number: default,
                                       reauthn: reauthn?)
    end

    def exceeded_otp_send_limit?
      return otp_rate_limiter.lock_out_user if otp_rate_limiter.exceeded_otp_send_limit?
    end

    def send_user_otp(method)
      current_user.create_direct_otp
      params = {
        to: phone_to_deliver_to,
        otp: current_user.direct_otp,
        expiration: Devise.direct_otp_valid_for.to_i / 60,
        channel: method.to_sym,
      }
      Telephony.send(send_otp_method_name, params)
    end

    def send_otp_method_name
      if authentication_context?
        :send_authentication_otp
      else
        :send_confirmation_otp
      end
    end

    def user_selected_default_number
      delivery_params[:otp_make_default_number]
    end

    def user_select_delivery_preference
      delivery_params[:otp_delivery_preference]
    end

    def delivery_params
      params.require(:otp_delivery_selection_form).permit(:otp_delivery_preference,
                                                          :otp_make_default_number,
                                                          :resend)
    end

    def phone_to_deliver_to
      return phone_configuration&.phone if authentication_context?

      user_session[:unconfirmed_phone]
    end

    def otp_rate_limiter
      @_otp_rate_limited ||= OtpRateLimiter.new(phone: phone_to_deliver_to, user: current_user)
    end

    def redirect_on_nothing_enabled
      redirect_to two_factor_options_url
    end

    def phone_redirect
      return unless phone_enabled?
      validate_otp_delivery_preference_and_send_code
      true
    end

    def redirect_url
      if TwoFactorAuthentication::PivCacPolicy.new(current_user).enabled?
        login_two_factor_piv_cac_url
      elsif TwoFactorAuthentication::WebauthnPolicy.new(current_user).enabled?
        login_two_factor_webauthn_url
      elsif TwoFactorAuthentication::AuthAppPolicy.new(current_user).enabled?
        login_two_factor_authenticator_url
      end
    end

    def backup_code_redirect
      return unless TwoFactorAuthentication::BackupCodePolicy.new(current_user).configured?
      redirect_to login_two_factor_backup_code_url
    end

    def non_phone_redirect
      url = redirect_url
      redirect_to url if url.present?
    end
  end
  # rubocop:enable Metrics/ClassLength
end
