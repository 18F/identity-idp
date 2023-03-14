module Idv
  class UnavailableController < ApplicationController
    def show
      if FeatureManagement.idv_available?
        if from_registration?
          return redirect_to sign_up_email_url
        else
          return redirect_to account_url
        end
      end

      show_without_redirect
    end

    def show_without_redirect
      analytics.vendor_outage(
        vendor_status: {
          acuant: IdentityConfig.store.vendor_status_acuant,
          lexisnexis_instant_verify: IdentityConfig.store.vendor_status_lexisnexis_instant_verify,
          lexisnexis_trueid: IdentityConfig.store.vendor_status_lexisnexis_trueid,
          sms: IdentityConfig.store.vendor_status_sms,
          voice: IdentityConfig.store.vendor_status_voice,
        },
        redirect_from: nil,
      )
      render 'idv/unavailable', status: :service_unavailable
    end

    private

    def from_registration?
      params[:from] == 'registration'
    end
  end
end
