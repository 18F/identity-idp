module Idv
  class UnavailableController < ApplicationController
    ALLOWED_FROM_LOCATIONS = [SignUp::RegistrationsController::CREATE_ACCOUNT]

    def show
      if FeatureManagement.idv_available?
        redirect_to sign_up_email_url if from_create_account?
        return
      end

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

      render status: :service_unavailable
    end

    private

    def from
      params[:from] if ALLOWED_FROM_LOCATIONS.include?(params[:from])
    end

    def from_create_account?
      from == SignUp::RegistrationsController::CREATE_ACCOUNT
    end
  end
end
