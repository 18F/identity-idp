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
      render :new, locals: { gpo_letter_available: gpo_letter_available }
    end

    def create
      result = otp_delivery_selection_form.submit(otp_delivery_selection_params)
      analytics.idv_phone_otp_delivery_selection_submitted(**result.to_h)
      return render_new_with_error_message unless result.success?
      send_phone_confirmation_otp_and_handle_result
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
      @idv_phone = idv_session.user_phone_confirmation_session.phone
    end

    def otp_delivery_selection_params
      params.permit(:otp_delivery_preference)
    end

    def render_new_with_error_message
      flash[:error] = t('idv.errors.unsupported_otp_delivery_method')
      render :new, locals: { gpo_letter_available: gpo_letter_available }
    end

    def send_phone_confirmation_otp_and_handle_result
      save_delivery_preference
      result = send_phone_confirmation_otp
      analytics.track_event(Analytics::IDV_PHONE_CONFIRMATION_OTP_SENT, result.to_h)
      if result.success?
        redirect_to idv_otp_verification_url
      else
        handle_send_phone_confirmation_otp_failure(result)
      end
    end

    def handle_send_phone_confirmation_otp_failure(result)
      if send_phone_confirmation_otp_rate_limited?
        handle_too_many_otp_sends
      else
        invalid_phone_number(result.extra[:telephony_response].error)
      end
    end

    def save_delivery_preference
      original_session = idv_session.user_phone_confirmation_session
      idv_session.user_phone_confirmation_session = PhoneConfirmation::ConfirmationSession.new(
        code: original_session.code,
        phone: original_session.phone,
        sent_at: original_session.sent_at,
        delivery_method: @otp_delivery_selection_form.otp_delivery_preference.to_sym,
      )
    end

    def otp_delivery_selection_form
      @otp_delivery_selection_form ||= Idv::OtpDeliveryMethodForm.new
    end

    def gpo_letter_available
      @gpo_letter_available ||= FeatureManagement.enable_gpo_verification? &&
                                !Idv::GpoMail.new(current_user).mail_spammed?
    end
  end
end
