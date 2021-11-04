class VendorOutageController < ApplicationController
  def show
    vendor_status = VendorStatus.new(
      sp: current_sp,
      from: session.delete(:vendor_outage_redirect),
      from_idv: session.delete(:vendor_outage_redirect_from_idv),
    )
    @specific_message = vendor_status.outage_message
    vendor_status.track_event(analytics)
  end
end
