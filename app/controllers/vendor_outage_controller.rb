# frozen_string_literal: true

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
    return false unless current_user
    policy = Idv::GpoVerifyByMailPolicy.new(current_user, resolved_authn_context_result)
    policy.send_letter_available?
  end
end
