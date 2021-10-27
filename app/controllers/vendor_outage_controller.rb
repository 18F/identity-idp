class VendorOutageController < ApplicationController
  include VendorOutageConcern

  def show
    tracking_data = {
      vendor_status: {
        acuant: IdentityConfig.store.vendor_status_acuant,
        lexisnexis_instant_verify: IdentityConfig.store.vendor_status_lexisnexis_instant_verify,
        lexisnexis_trueid: IdentityConfig.store.vendor_status_lexisnexis_trueid,
      },
      redirect_from: session.delete(:vendor_outage_redirect),
    }
    analytics.track_event(Analytics::VENDOR_OUTAGE, tracking_data)
    @specific_message = outage_message
  end
end
