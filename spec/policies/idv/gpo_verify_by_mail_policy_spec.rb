# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Idv::GpoVerifyByMailPolicy do
  let(:subject) { described_class.new(user, resolved_authn_context_result) }
  let(:user) { create(:user) }
  let(:two_pieces_of_fair_evidence) { false }
  let(:resolved_authn_context_result) do
    Vot::Parser::Result.no_sp_result.with(
      two_pieces_of_fair_evidence?: two_pieces_of_fair_evidence,
    )
  end

  describe '#resend_letter_available?' do
    context 'when the feature flag is off' do
      before do
        allow(IdentityConfig.store).to receive(:enable_usps_verification)
          .and_return false
      end

      it 'returns false' do
        expect(subject.resend_letter_available?).to eq false
      end
    end

    context 'when the feature flag is on' do
      before do
        allow(IdentityConfig.store).to receive(:enable_usps_verification)
          .and_return true
      end

      it 'returns false when the user is rate-limited' do
        enqueue_gpo_letter_for(user, at_time: 4.days.ago)
        enqueue_gpo_letter_for(user, at_time: 3.days.ago)
        enqueue_gpo_letter_for(user, at_time: 2.days.ago)

        expect(subject.resend_letter_available?).to eq false
      end

      it 'returns false when the profile is too old' do
        create(:profile, :verify_by_mail_pending, user: user, created_at: 90.days.ago)

        expect(subject.resend_letter_available?).to eq false
      end

      it 'returns true if not rate-limited and the profile is current' do
        create(:profile, :verify_by_mail_pending, user: user)

        expect(subject.resend_letter_available?).to eq true
      end
    end
  end

  describe '#send_letter_available?' do
    context 'when the feature flag is off' do
      before do
        allow(IdentityConfig.store).to receive(:enable_usps_verification)
          .and_return false
      end

      it 'returns false' do
        expect(subject.send_letter_available?).to eq false
      end
    end

    context 'when the feature flag is on' do
      before do
        allow(IdentityConfig.store).to receive(:enable_usps_verification)
          .and_return true
      end

      it 'returns true when the user is not rate-limited' do
        expect(subject.send_letter_available?).to eq true
      end

      it 'returns false when the user is rate-limited' do
        enqueue_gpo_letter_for(user, at_time: 4.days.ago)
        enqueue_gpo_letter_for(user, at_time: 3.days.ago)
        enqueue_gpo_letter_for(user, at_time: 2.days.ago)

        expect(subject.send_letter_available?).to eq false
      end

      it 'returns true even if the profile is too old' do
        create(:profile, :verify_by_mail_pending, user: user, created_at: 90.days.ago)
        expect(subject.send_letter_available?).to eq true
      end

      context 'the 2 pieces of fair evidence requirement is present' do
        let(:two_pieces_of_fair_evidence) { true }

        it 'returns false' do
          expect(subject.send_letter_available?).to eq(false)
        end
      end

      context 'user has a pending in-person enrollment' do
        let!(:in_person_enrollment) { create(:in_person_enrollment, :pending, user: user) }

        it 'returns false' do
          expect(subject.send_letter_available?).to eq(false)
        end
      end

      context 'user has an establishing in-person enrollment' do
        let!(:in_person_enrollment) { create(:in_person_enrollment, :establishing, user: user) }

        it 'returns false' do
          expect(subject.send_letter_available?).to eq(false)
        end
      end
    end
  end

  describe '#rate_limited?' do
    let(:max_letter_request_events) { 2 }
    let(:letter_request_events_window_days) { 30 }
    let(:minimum_wait_before_another_usps_letter_in_hours) { 24 }

    before do
      allow(IdentityConfig.store).to receive(:max_mail_events)
        .and_return(max_letter_request_events)
      allow(IdentityConfig.store).to receive(:max_mail_events_window_in_days)
        .and_return(letter_request_events_window_days)
      allow(IdentityConfig.store).to receive(:minimum_wait_before_another_usps_letter_in_hours)
        .and_return(minimum_wait_before_another_usps_letter_in_hours)
    end

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
