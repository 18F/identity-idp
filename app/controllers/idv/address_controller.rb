module Idv
  class AddressController < ApplicationController
    include IdvSession
    include IdvFailureConcern

    attr_reader :idv_form

    before_action :confirm_two_factor_authenticated

    def new
      analytics.track_event(Analytics::IDV_ADDRESS_VISIT)
      set_idv_form
      render 'idv/address'
    end

    def update
      set_idv_form
      form_result = idv_form.submit(profile_params)
      analytics.track_event(Analytics::IDV_ADDRESS_SUBMITTED, form_result.to_h)
      if form_result.success?
        success
      else
        failure
      end
    end

    private

    def success
      profile_params.each do |key|
        user_session['idv/doc_auth']['pii_from_doc'][key] = profile_params[key]
      end
      redirect_to idv_doc_auth_url
    end

    def failure
      reason = params[:reason].to_sym
      render_idv_step_failure(:sessions, reason)
    end

    def set_idv_form
      @idv_form ||= Idv::AddressForm.new(
        user: current_user,
        previous_params: idv_session.previous_profile_step_params,
      )
    end

    def profile_params
      params.require(:idv_form).permit(Idv::AddressForm::ATTRIBUTES)
    end

    def failure_url(reason)
      idv_session_failure_url(reason)
    end
  end
end
