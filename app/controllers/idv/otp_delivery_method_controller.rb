module Idv
  class OtpDeliveryMethodController < ApplicationController
    include IdvSession
    include PhoneOtpRateLimitable
    include PhoneOtpSendable

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
      return render_new_with_error_message unless result.success?
      send_phone_confirmation_otp_and_handle_result
    rescue Telephony::TelephonyError => telephony_error
      invalid_phone_number(telephony_error)
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
      @idv_phone = PhoneFormatter.format(idv_session.applicant[:phone])
    end

    def otp_delivery_selection_params
      params.permit(:otp_delivery_preference)
    end

    def render_new_with_error_message
      flash[:error] = t('idv.errors.unsupported_otp_delivery_method')
      render :new
    end

    def send_phone_confirmation_otp_and_handle_result
      save_delivery_preference_in_session
      result = send_phone_confirmation_otp
      analytics.track_event(Analytics::IDV_PHONE_CONFIRMATION_OTP_SENT, result.to_h)
      if send_phone_confirmation_otp_rate_limited?
        handle_too_many_otp_sends
      else
        redirect_to idv_otp_verification_url
      end
    end

    def save_delivery_preference_in_session
      idv_session.phone_confirmation_otp_delivery_method =
        @otp_delivery_selection_form.otp_delivery_preference
    end

    def otp_delivery_selection_form
      @otp_delivery_selection_form ||= Idv::OtpDeliveryMethodForm.new
    end
  end
end
