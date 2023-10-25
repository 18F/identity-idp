# frozen_string_literal: true

module Idv
  class UnavailableController < ApplicationController
    ALLOWED_FROM_LOCATIONS = [SignUp::RegistrationsController::CREATE_ACCOUNT]

    before_action :redirect_if_idv_available_and_from_create_account

    def show
      analytics.vendor_outage(
        vendor_status: {
          acuant: IdentityConfig.store.vendor_status_acuant,
          lexisnexis_instant_verify: IdentityConfig.store.vendor_status_lexisnexis_instant_verify,
          lexisnexis_trueid: IdentityConfig.store.vendor_status_lexisnexis_trueid,
          sms: IdentityConfig.store.vendor_status_sms,
          voice: IdentityConfig.store.vendor_status_voice,
        },
        redirect_from: from,
      )
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
