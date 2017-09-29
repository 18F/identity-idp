require 'rails_helper'

describe VerifyAccountForm do
  subject(:form) do
    VerifyAccountForm.new(user: user, otp: entered_otp)
  end

  let(:user) { pending_profile.user }
  let(:entered_otp) { otp }
  let(:otp) { 'ABC123' }
  let(:code_sent_at) { Time.zone.now }
  let(:pending_profile) { create(:profile, deactivation_reason: :verification_pending) }

  before do
    next if pending_profile.blank?

    create(
      :usps_confirmation_code,
      otp_fingerprint: Pii::Fingerprinter.fingerprint(otp),
      code_sent_at: code_sent_at,
      profile: pending_profile
    )
  end

  describe '#valid?' do
    context 'when required attributes are not present' do
      let(:entered_otp) { nil }

      it 'is invalid' do
        expect(subject).to_not be_valid
        expect(subject.errors[:otp]).to eq [t('errors.messages.blank')]
      end
    end

    context 'when there is no pending profile ' do
      let(:pending_profile) { nil }
      let(:user) { build_stubbed(:user) }

      it 'is invalid' do
        expect(subject).to_not be_valid
        expect(subject.errors[:base]).to eq [t('errors.messages.no_pending_profile')]
      end
    end

    context 'OTP crockford normalizing' do
      context 'when the entered OTP has lowercase' do
        let(:entered_otp) { 'abcdef12345' }
        let(:otp) { 'ABCDEF12345' }

        it 'is valid' do
          expect(subject).to be_valid
        end
      end

      context 'when the entered OTP has ohs instead of zeroes' do
        let(:entered_otp) { 'oOoOoOoOoO' }
        let(:otp) { '0000000000' }

        it 'is valid' do
          expect(subject).to be_valid
        end
      end
    end

    context 'when OTP does not match' do
      let(:entered_otp) { 'wrong' }

      it 'is invalid' do
        expect(subject).to_not be_valid
        expect(subject.errors[:otp]).to eq [t('errors.messages.confirmation_code_incorrect')]
      end
    end

    context 'when OTP is expired' do
      let(:code_sent_at) { 11.days.ago }

      it 'is invalid' do
        expect(subject).to_not be_valid
        expect(subject.errors[:otp]).to eq [t('errors.messages.usps_otp_expired')]
      end
    end
  end

  describe '#submit' do
    context 'correct OTP' do
      it 'returns true' do
        expect(subject.submit).to eq true
      end

      it 'activates the pending profile' do
        expect(pending_profile).to_not be_active

        subject.submit

        expect(pending_profile.reload).to be_active
      end
    end

    context 'incorrect OTP' do
      let(:entered_otp) { 'wrong' }

      it 'clears form' do
        subject.submit

        expect(subject.otp).to be_nil
      end
    end
  end
end
