class VendorOutageController < ApplicationController
  include VendorOutageConcern

  def new
    tracking_data = {
      outages: {
        acuant: IdentityConfig.store.outage_acuant,
        lexisnexis_instant_verify: IdentityConfig.store.outage_lexisnexis_instant_verify,
        lexisnexis_trueid: IdentityConfig.store.outage_lexisnexis_trueid,
      },
      redirect_from: session.delete(:vendor_outage_redirect),
    }
    analytics.track_event(Analytics::VENDOR_OUTAGE, tracking_data)
    @specific_message = outage_message
  end
end
