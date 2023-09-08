module Idv
  class AddressController < ApplicationController
    include IdvStepConcern

    before_action :confirm_document_capture_complete

    def new
      analytics.idv_address_visit

      @presenter = AddressPresenter.new(pii: pii_from_doc)
    end

    def update
      form_result = idv_form.submit(profile_params)
      analytics.idv_address_submitted(**form_result.to_h)
      capture_address_edited(form_result)
      if form_result.success?
        success
      else
        failure
      end
    end

    private

    def idv_form
      Idv::AddressForm.new(pii_from_doc)
    end

    def success
      # Make sure pii_from_doc is available in both places so we can 
      # update the address for both and keep them in sync
      idv_session.pii_from_doc = pii_from_doc
      profile_params.each do |key, value|
        idv_session.pii_from_doc[key] = value
      end
      flow_session[:pii_from_doc] = idv_session.pii_from_doc
      redirect_to idv_verify_info_url
    end

    def failure
      redirect_to idv_address_url
    end

    def profile_params
      params.require(:idv_form).permit(Idv::AddressForm::ATTRIBUTES)
    end

    def capture_address_edited(result)
      address_edited = result.to_h[:address_edited]
      idv_session.address_edited = true if address_edited
    end
  end
end
