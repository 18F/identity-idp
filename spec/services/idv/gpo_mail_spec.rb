require 'rails_helper'

RSpec.describe Idv::GpoMail do
  let(:user) { create(:user) }
  let(:subject) { Idv::GpoMail.new(user) }
  let(:max_letter_request_events) { 2 }
  let(:letter_request_events_window_days) { 30 }
  let(:minimum_wait_before_another_usps_letter_in_hours) { 24 }

  before do
    allow(IdentityConfig.store).to receive(:max_mail_events).
      and_return(max_letter_request_events)
    allow(IdentityConfig.store).to receive(:max_mail_events_window_in_days).
      and_return(letter_request_events_window_days)
    allow(IdentityConfig.store).to receive(:minimum_wait_before_another_usps_letter_in_hours).
      and_return(minimum_wait_before_another_usps_letter_in_hours)
  end


  def enqueue_gpo_letter_for(user, at_time: Time.zone.now)
    profile = create(
      :profile,
      user: user,
      gpo_verification_pending_at: at_time,
    )

    GpoConfirmationMaker.new(
      pii: Idp::Constants::MOCK_IDV_APPLICANT,
      service_provider: nil,
      profile: profile,
    ).perform

    profile.gpo_confirmation_codes.last.update(
      created_at: at_time,
      updated_at: at_time,
    )
  end
end
