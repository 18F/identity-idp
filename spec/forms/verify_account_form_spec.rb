require 'rails_helper'

describe VerifyAccountForm do
  subject(:form) do
    VerifyAccountForm.new(user: user, otp: otp, pii_attributes: pii_attributes)
  end

  let(:user) { pending_profile.user }
  let(:otp) { 'abc123' }
  let(:pii_attributes) { Pii::Attributes.new_from_hash(otp: otp) }
  let(:pending_profile) { create(:profile, deactivation_reason: :verification_pending) }

  describe '#valid?' do
    let(:valid_otp?) { true }

    before do
      allow(form).to receive(:valid_otp?).and_return(valid_otp?)
    end

    context 'when required attributes are not present' do
      let(:otp) { nil }

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

    context 'when OTP does not match' do
      let(:valid_otp?) { false }

      it 'is invalid' do
        expect(subject).to_not be_valid
        expect(subject.errors[:otp]).to eq [t('errors.messages.otp_incorrect')]
      end
    end
  end

  describe '#submit' do
    let(:valid_otp?) { true }

    before do
      allow(form).to receive(:valid_otp?).and_return(valid_otp?)
    end

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
      let(:valid_otp?) { false }

      it 'clears form' do
        subject.submit

        expect(subject.otp).to be_nil
      end
    end
  end
end
