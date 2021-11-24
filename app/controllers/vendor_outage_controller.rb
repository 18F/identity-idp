class VendorOutageController < ApplicationController
  def show
    vendor_status = VendorStatus.new(
      sp: current_sp,
      from: session.delete(:vendor_outage_redirect),
      from_idv: session.delete(:vendor_outage_redirect_from_idv),
    )
    @specific_message = vendor_status.outage_message
    @show_gpo_option = from_idv_phone? && gpo_letter_available?
    vendor_status.track_event(analytics)
  end

  private

  def from_idv_phone?
    params[:from] == 'idv_phone'
  end

  def gpo_letter_available?
    FeatureManagement.enable_gpo_verification? &&
      current_user &&
      !Idv::GpoMail.new(current_user).mail_spammed?
  end
end
