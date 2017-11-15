module Verify
  class AddressController < ApplicationController
    include IdvStepConcern
    require 'pry'

    before_action :confirm_step_needed

    def index; end

    def create
      response = Idv::AddressDeliveryMethodForm.new.submit(address_delivery_params.to_h.symbolize_keys)

      if response.success? 
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
      if address_delivery_params[:address_delivery_method] == 'phone'
        verify_phone_path
      elsif address_delivery_params[:address_delivery_method] == 'usps'
        verify_usps_path
      end
    end

    def confirm_step_needed
      redirect_to verify_review_path if idv_session.address_mechanism_chosen?
    end
  end
end
