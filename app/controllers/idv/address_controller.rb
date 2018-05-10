module Idv
  class AddressController < ApplicationController
    include IdvStepConcern

    before_action :confirm_step_needed

    def index; end

    def create
      result = Idv::AddressDeliveryMethodForm.new.submit(address_delivery_params)

      analytics.track_event(Analytics::IDV_ADDRESS_VERIFICATION_SELECTION, result.to_h)

      if result.success?
        redirect_to address_delivery_destination
      else
        render :index
      end
    end

    private

    def address_delivery_params
      params.permit(:address_delivery_method)
    end

    def address_delivery_destination
      destination = address_delivery_params[:address_delivery_method]
      if destination == 'phone'
        idv_phone_path
      elsif destination == 'usps'
        idv_usps_path
      end
    end

    def confirm_step_needed
      redirect_to idv_review_url if idv_session.address_mechanism_chosen?
    end
  end
end
