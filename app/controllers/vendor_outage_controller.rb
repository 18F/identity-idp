class VendorOutageController < ApplicationController
  def show
    outage_status = OutageStatus.new

    @specific_message = outage_status.outage_message
    @show_gpo_option = from_idv_phone? && gpo_letter_available?
    outage_status.track_event(analytics)
  end

  private

  def from_idv_phone?
    params[:from] == 'idv_phone'
  end

  def gpo_letter_available?
    FeatureManagement.gpo_verification_enabled? &&
      current_user &&
      !Idv::GpoMail.new(current_user).rate_limited?
  end
end
