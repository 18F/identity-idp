module Idv
  class OtpDeliveryMethodController < ApplicationController
    include IdvSession
    include PhoneConfirmation

    before_action :confirm_phone_step_complete
    before_action :confirm_step_needed
    before_action :idv_phone # Memoize to use ivar in the view

    def new
      analytics.track_event(Analytics::IDV_PHONE_OTP_DELIVERY_SELECTION_VISIT)
    end

    def create
      result = otp_delivery_selection_form.submit(otp_delivery_selection_params)
      analytics.track_event(Analytics::IDV_PHONE_OTP_DELIVERY_SELECTION_SUBMITTED, result.to_h)
      if result.success?
        prompt_to_confirm_idv_phone
      else
        render :new
      end
    end

    private

    def confirm_phone_step_complete
      redirect_to idv_phone_url if idv_session.vendor_phone_confirmation != true
    end

    def confirm_step_needed
      redirect_to idv_review_url if idv_session.address_verification_mechanism != 'phone' ||
                                    idv_session.user_phone_confirmation == true
    end

    def idv_phone
      @idv_phone ||= PhoneFormatter.format(idv_session.applicant[:phone])
    end

    def prompt_to_confirm_idv_phone
      prompt_to_confirm_phone(
        phone: idv_phone,
        context: 'idv',
        selected_delivery_method: otp_delivery_selection_form.otp_delivery_preference
      )
    end

    def otp_delivery_selection_params
      params.require(:otp_delivery_selection_form).permit(
        :otp_delivery_preference
      )
    end

    def otp_delivery_selection_form
      @otp_delivery_selection_form ||= Idv::OtpDeliveryMethodForm.new
    end
  end
end
