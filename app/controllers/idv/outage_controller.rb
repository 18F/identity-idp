module Idv
  class OutageController < ApplicationController
    def show
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
    end
  end
end