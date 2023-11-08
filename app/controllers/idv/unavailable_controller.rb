module Idv
  class UnavailableController < ApplicationController
    ALLOWED_FROM_LOCATIONS = [SignUp::RegistrationsController::CREATE_ACCOUNT]

    before_action :redirect_if_idv_available_and_from_create_account

    def show
      OutageStatus.new.track_event(analytics, redirect_from: from)
    end

    private

    def from
      params[:from] if ALLOWED_FROM_LOCATIONS.include?(params[:from])
    end

    def from_create_account?
      from == SignUp::RegistrationsController::CREATE_ACCOUNT
    end

    def redirect_if_idv_available_and_from_create_account
      redirect_to sign_up_email_url if FeatureManagement.idv_available? && from_create_account?
    end
  end
end
