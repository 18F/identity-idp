# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Idv::GpoVerifyByMailPolicy do
  describe '#resend_letter_available?' do
    let(:subject) { described_class.new(user).resend_letter_available? }
    let(:user) { create(:user) }

    context 'when the feature flag is off' do
      before do
        allow(IdentityConfig.store).to receive(:enable_usps_verification).
          and_return false
      end

      it 'returns false' do
        expect(subject).to eq false
      end
    end

    context 'when the feature flag is on' do
      before do
        allow(IdentityConfig.store).to receive(:enable_usps_verification).
          and_return true
      end

      context 'when the user is rate limited' do
        # copypasta
        before do
          enqueue_gpo_letter_for(user, at_time: 4.days.ago)
          enqueue_gpo_letter_for(user, at_time: 3.days.ago)
          enqueue_gpo_letter_for(user, at_time: 2.days.ago)
        end

        it 'returns false' do
          expect(subject).to eq false
        end
      end

      context 'when the user has a too-old profile' do
        before do
          create(:profile, :verify_by_mail_pending, user: user, created_at: 90.days.ago)
        end

        it 'returns false' do
          expect(subject).to eq(false)
        end
      end

      context 'when the user has a current profile and is not rate limited' do
        before do
          create(:profile, :verify_by_mail_pending, user: user)
        end

        it 'returns true' do
          expect(subject).to eq(true)
        end
      end
    end
  end

  # FIXME: Straight-up copied and pasted from GpoMailSpec
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
