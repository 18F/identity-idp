module Idv
  class OtpDeliveryMethodController < ApplicationController
    include IdvSession

    before_action :confirm_two_factor_authenticated
    before_action :confirm_phone_step_complete
    before_action :confirm_step_needed
    before_action :set_otp_delivery_method_presenter
    before_action :set_otp_delivery_selection_form

    def new; end

    def create
      result = @otp_delivery_selection_form.submit(otp_delivery_selection_params)
      if result.success?
        save_delivery_preference_in_session
        redirect_to idv_send_phone_otp_url
      else
        render :new
      end
    end

    private

    def confirm_phone_step_complete
      redirect_to idv_review_url if idv_session.vendor_phone_confirmation != true
    end

    def confirm_step_needed
      redirect_to idv_review_url if idv_session.address_verification_mechanism != 'phone' ||
                                    idv_session.user_phone_confirmation == true
    end

    def otp_delivery_selection_params
      params.require(:otp_delivery_selection_form).permit(
        :otp_delivery_preference
      )
    end

    def set_otp_delivery_method_presenter
      @set_otp_delivery_method_presenter = Idv::OtpDeliveryMethodPresenter.new(
        idv_session.params[:phone]
      )
    end

    def set_otp_delivery_selection_form
      @otp_delivery_selection_form = OtpDeliverySelectionForm.new(
        current_user,
        idv_session.params[:phone],
        'idv'
      )
    end

    def save_delivery_preference_in_session
      idv_session.phone_confirmation_otp_delivery_method =
        @otp_delivery_selection_form.otp_delivery_preference
    end
  end
end
