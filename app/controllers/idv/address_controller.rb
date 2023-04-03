module Idv
  class AddressController < ApplicationController
    include IdvSession
    include IdvStepConcern

    before_action :confirm_two_factor_authenticated
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

    # def confirm_document_capture_complete
    #   @pii = user_session.dig('idv/doc_auth', 'pii_from_doc')
    #   return if @pii.present?
    #
    #   flow_path = user_session.dig('idv/doc_auth', :flow_path)
    #
    #   if IdentityConfig.store.doc_auth_document_capture_controller_enabled &&
    #      flow_path == 'standard'
    #     redirect_to idv_document_capture_url
    #   else
    #     redirect_to idv_doc_auth_url
    #   end
    # end

    def idv_form
      Idv::AddressForm.new(pii_from_doc)
    end

    def success
      profile_params.each do |key, value|
        user_session['idv/doc_auth']['pii_from_doc'][key] = value
      end
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
      user_session['idv/doc_auth']['address_edited'] = address_edited if address_edited
    end
  end
end
