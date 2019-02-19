module Idv
  class AddressController < ApplicationController
    include IdvSession
    include IdvFailureConcern

    before_action :confirm_two_factor_authenticated

    def new
      analytics.track_event(Analytics::IDV_ADDRESS_VISIT)
    end

    def update
      form_result = idv_form.submit(profile_params)
      analytics.track_event(Analytics::IDV_ADDRESS_SUBMITTED, form_result.to_h)
      if form_result.success?
        success
      else
        failure
      end
    end

    private

    def idv_form
      Idv::AddressForm.new(
        user: current_user,
        previous_params: idv_session.previous_profile_step_params,
      )
    end

    def success
      profile_params.each do |key, value|
        user_session['idv/doc_auth']['pii_from_doc'][key] = value
      end
      redirect_to idv_doc_auth_url
    end

    def failure
      redirect_to idv_address_url
    end

    def profile_params
      params.require(:idv_form).permit(Idv::AddressForm::ATTRIBUTES)
    end
  end
end
