module Idv
  class PhoneController < ApplicationController
    include IdvSession

    before_action :confirm_two_factor_authenticated

    def new
      @idv_phone_form = Idv::PhoneForm.new(idv_params, current_user)
    end

    def create
      @idv_phone_form = Idv::PhoneForm.new(idv_params, current_user)

      if @idv_phone_form.submit(profile_params)
        redirect_to idv_sessions_review_url
        idv_session[:params] = @idv_phone_form.idv_params
      else
        render :new
      end
    end

    private

    def profile_params
      params.require(:idv_phone_form).permit(:phone)
    end
  end
end
