class VendorOutageController < ApplicationController
  def show
    @specific_message = OutageStatus.new.outage_message
    @show_gpo_option = from_idv_phone? && gpo_letter_available?
    OutageStatus.new.track_event(analytics)
  end

  private

  def from_idv_phone?
    params[:from] == 'idv_phone'
  end

  def gpo_letter_available?
    FeatureManagement.gpo_verification_enabled? &&
      current_user &&
      !Idv::GpoMail.new(current_user).mail_spammed?
  end
end
