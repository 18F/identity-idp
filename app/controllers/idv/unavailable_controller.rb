module Idv
  class UnavailableController < ApplicationController
    def attempt_redirect
      if FeatureManagement.idv_available?
        if from_create_account?
          return redirect_to sign_up_email_url
        else
          return redirect_to account_url
        end
      end

      show
    end

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
      render 'idv/unavailable', status: :service_unavailable
    end

    private

    def from
      allowed = [SignUp::RegistrationsController::CREATE_ACCOUNT]
      params[:from] if params[:from].present? && allowed.include?(params[:from])
    end

    def from_create_account?
      from == SignUp::RegistrationsController::CREATE_ACCOUNT
    end
  end
end
