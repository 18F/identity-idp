module Idv
  class JurisdictionController < ApplicationController
    include IdvSession

    before_action :confirm_two_factor_authenticated
    before_action :confirm_idv_attempts_allowed
    before_action :confirm_idv_needed
    before_action :set_jurisdiction_form, only: %i[new create]

    def new
      analytics.track_event(Analytics::IDV_JURISDICTION_VISIT)
    end

    def create
      result = @jurisdiction_form.submit(jurisdiction_params)
      analytics.track_event(Analytics::IDV_JURISDICTION_FORM, result.to_h)
      user_session[:idv_jurisdiction] = @jurisdiction_form.state

      if result.success?
        redirect_to idv_session_url
      else
        # The only invalid result here is due to an unsupported jurisdiction
        # and if it is missing from the params, it will be stopped by
        # `strong_params`.
        redirect_to idv_jurisdiction_fail_url(:unsupported_jurisdiction)
      end
    end

    def show
      @state = user_session[:idv_jurisdiction]
      @reason = params[:reason]
    end

    def jurisdiction_params
      params.require(:jurisdiction).permit(*Idv::JurisdictionForm::ATTRIBUTES)
    end

    private

    def set_jurisdiction_form
      @jurisdiction_form ||= Idv::JurisdictionForm.new
    end
  end
end
