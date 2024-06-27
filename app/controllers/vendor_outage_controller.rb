# frozen_string_literal: true

class VendorOutageController < ApplicationController
  include Idv::VerifyByMailConcern

  def show
    outage_status = OutageStatus.new

    @specific_message = outage_status.outage_message
    @show_gpo_option = from_idv_phone? &&
                       user_signed_in? &&
                       gpo_verify_by_mail_policy.send_letter_available?
    outage_status.track_event(analytics)
  end

  private

  def from_idv_phone?
    params[:from] == 'idv_phone'
  end
end
