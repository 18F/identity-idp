module Idv
  class UnavailableController < ApplicationController
    def index
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
  end
end
