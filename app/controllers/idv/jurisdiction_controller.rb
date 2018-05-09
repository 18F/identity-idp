module Idv
  class JurisdictionController < ApplicationController
    include IdvSession

    before_action :confirm_two_factor_authenticated
    before_action :confirm_idv_attempts_allowed
    before_action :confirm_idv_needed

    def new
      @jurisdiction_form = Idv::JurisdictionForm.new
      analytics.track_event(Analytics::IDV_JURISDICTION_VISIT)
    end

    def create
      @jurisdiction_form = Idv::JurisdictionForm.new
      result = @jurisdiction_form.submit(jurisdiction_params)
      analytics.track_event(Analytics::IDV_JURISDICTION_FORM, result.to_h)
      user_session[:jurisdiction] = @jurisdiction_form.state

      if result.success?
        redirect_to idv_session_url
      elsif @jurisdiction_form.unsupported_jurisdiction?
        redirect_to idv_jurisdiction_fail_url(:unsupported_jurisdiction)
      else
        render :new
      end
    end

    def show
      @state = user_session[:jurisdiction]
      @reason = params[:reason]
    end

    def jurisdiction_params
      params.require(:jurisdiction).permit(*Idv::JurisdictionForm::ATTRIBUTES)
    end
  end
end
