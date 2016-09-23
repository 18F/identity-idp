module Idv
  class SessionsController < ApplicationController
    include IdvSession

    before_action :confirm_two_factor_authenticated
    before_action :confirm_idv_attempts_allowed
    before_action :confirm_idv_needed

    helper_method :idv_profile_form

    def new
      @using_mock_vendor = idv_vendor.pick == :mock
    end

    def create
      idv_session.params.merge!(profile_params)
      submit_profile
    end

    private

    def submit_profile
      if idv_profile_form.submit(profile_params)
        redirect_to idv_finance_url
      else
        render :new
      end
    end

    def idv_profile_form
      @_idv_profile_form ||= Idv::ProfileForm.new((idv_session.params || {}), current_user)
    end

    def profile_params
      params.require(:profile).permit(
        :first_name, :last_name, :dob, :ssn, :address1, :address2, :city, :state, :zipcode
      )
    end
  end
end
