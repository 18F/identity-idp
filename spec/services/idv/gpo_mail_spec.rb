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

  describe '#rate_limited?' do
    context 'when no letters have been requested' do
      it 'returns false' do
        expect(subject.rate_limited?).to eq false
      end
    end

    context 'when too many letters have been requested within the limiting window' do
      before do
        enqueue_gpo_letter_for(user, at_time: 4.days.ago)
        enqueue_gpo_letter_for(user, at_time: 3.days.ago)
        enqueue_gpo_letter_for(user, at_time: 2.days.ago)
      end

      it 'is true' do
        expect(subject.rate_limited?).to eq true
      end

      context 'but the window limit is disabled due to a 0 window size' do
        let(:letter_request_events_window_days) { 0 }

        it 'is false' do
          expect(subject.rate_limited?).to eq false
        end
      end

      context 'but the window limit is disabled due to a 0 window count' do
        let(:max_letter_request_events) { 0 }

        it 'is false' do
          expect(subject.rate_limited?).to eq false
        end
      end
    end

    context 'when a letter has been requested too recently' do
      before do
        enqueue_gpo_letter_for(user)
      end

      it 'is true' do
        expect(subject.rate_limited?).to eq true
      end

      context 'but the too-recent limit is disabled' do
        let(:minimum_wait_before_another_usps_letter_in_hours) { 0 }

        it 'is false' do
          expect(subject.rate_limited?).to eq false
        end
      end

      context 'but the letter is not attached to their pending profile' do
        # This can happen if the user resets their password while a GPO
        # letter is pending.

        before do
          user.gpo_verification_pending_profile.update(
            gpo_verification_pending_at: nil,
          )
        end

        it 'returns false' do
          expect(subject.rate_limited?).to be false
        end
      end
    end
  end

  def enqueue_gpo_letter_for(user, at_time: Time.zone.now)
    profile = create(
      :profile,
      user:,
      gpo_verification_pending_at: at_time,
    )

    GpoConfirmationMaker.new(
      pii: {},
      service_provider: nil,
      profile:,
    ).perform

    profile.gpo_confirmation_codes.last.update(
      created_at: at_time,
      updated_at: at_time,
    )
  end
end
