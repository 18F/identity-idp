module Idv
  class OtpDeliveryMethodController < ApplicationController
    include IdvSession
    include PhoneConfirmation

    before_action :confirm_phone_step_complete
    before_action :confirm_step_needed
    before_action :set_otp_delivery_method_presenter
    before_action :set_otp_delivery_selection_form

    def new; end

    def create
      result = @otp_delivery_selection_form.submit(otp_delivery_selection_params)
      if result.success?
        prompt_to_confirm_phone(
          phone: idv_session.params[:phone],
          context: 'idv',
          selected_delivery_method: @otp_delivery_selection_form.otp_delivery_preference
        )
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
  end
end
