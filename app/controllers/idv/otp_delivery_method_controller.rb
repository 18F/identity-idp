module Idv
  class OtpDeliveryMethodController < ApplicationController
    include IdvSession
    include PhoneOtpRateLimitable

    # confirm_two_factor_authenticated before action is in PhoneOtpRateLimitable
    before_action :confirm_phone_step_complete
    before_action :confirm_step_needed
    before_action :set_idv_phone

    def new
      analytics.track_event(Analytics::IDV_PHONE_OTP_DELIVERY_SELECTION_VISIT)
    end

    def create
      result = otp_delivery_selection_form.submit(otp_delivery_selection_params)
      analytics.track_event(Analytics::IDV_PHONE_OTP_DELIVERY_SELECTION_SUBMITTED, result.to_h)
      return render(:new) unless result.success?
      send_phone_confirmation_otp
    rescue Twilio::REST::RestError, PhoneVerification::VerifyError => exception
      invalid_phone_number(exception)
    end

    private

    def confirm_phone_step_complete
      redirect_to idv_phone_url if idv_session.vendor_phone_confirmation != true
    end

    def confirm_step_needed
      redirect_to idv_review_url if idv_session.address_verification_mechanism != 'phone' ||
                                    idv_session.user_phone_confirmation == true
    end

    def set_idv_phone
      @idv_phone = PhoneFormatter.format(idv_session.params[:phone])
    end

    def otp_delivery_selection_params
      params.require(:otp_delivery_selection_form).permit(
        :otp_delivery_preference
      )
    end

    def send_phone_confirmation_otp
      save_delivery_preference_in_session
      result = send_phone_confirmation_otp_service.call
      analytics.track_event(Analytics::IDV_PHONE_CONFIRMATION_OTP_SENT, result.to_h)
      if send_phone_confirmation_otp_service.user_locked_out?
        handle_too_many_otp_sends
      else
        redirect_to idv_otp_verification_url
      end
    end

    def save_delivery_preference_in_session
      idv_session.phone_confirmation_otp_delivery_method =
        @otp_delivery_selection_form.otp_delivery_preference
    end

    def send_phone_confirmation_otp_service
      @send_phone_confirmation_otp_service ||= Idv::SendPhoneConfirmationOtp.new(
        user: current_user,
        idv_session: idv_session,
        locale: user_locale
      )
    end

    def user_locale
      available_locales = PhoneVerification::AVAILABLE_LOCALES
      http_accept_language.language_region_compatible_from(available_locales)
    end

    def otp_delivery_selection_form
      @otp_delivery_selection_form ||= Idv::OtpDeliveryMethodForm.new
    end

    def invalid_phone_number(exception)
      twilio_errors = TwilioErrors::REST_ERRORS.merge(TwilioErrors::VERIFY_ERRORS)
      flash[:error] = twilio_errors.fetch(exception.code, t('errors.messages.otp_failed'))
      redirect_to idv_phone_url
    end
  end
end
