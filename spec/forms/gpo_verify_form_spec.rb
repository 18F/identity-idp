require 'rails_helper'

describe GpoVerifyForm do
  subject(:form) do
    GpoVerifyForm.new(user: user, pii: applicant, otp: entered_otp)
  end

  let(:user) { create(:user, :signed_up) }
  let(:applicant) { Idp::Constants::MOCK_IDV_APPLICANT_WITH_PHONE.merge(same_address_as_id: true) }
  let(:entered_otp) { otp }
  let(:otp) { 'ABC123' }
  let(:code_sent_at) { Time.zone.now }
  let(:pending_profile) {
    create(
      :profile,
      user: user,
      deactivation_reason: :gpo_verification_pending,
      proofing_components: proofing_components,
    )
  }
  let(:proofing_components) { nil }

  before do
    next if pending_profile.blank?

    create(
      :gpo_confirmation_code,
      otp_fingerprint: Pii::Fingerprinter.fingerprint(otp),
      code_sent_at: code_sent_at,
      profile: pending_profile,
    )
  end

  describe '#valid?' do
    context 'when required attributes are not present' do
      let(:entered_otp) { nil }

      it 'is invalid' do
        result = subject.submit
        expect(result.success?).to eq(false)
        expect(result.errors[:otp]).to eq [t('errors.messages.blank')]
      end
    end

    context 'when there is no pending profile ' do
      let(:pending_profile) { nil }
      let(:user) { build_stubbed(:user) }

      it 'is invalid' do
        result = subject.submit
        expect(result.success?).to eq(false)
        expect(result.errors[:base]).to eq [t('errors.messages.no_pending_profile')]
      end
    end

    context 'OTP crockford normalizing' do
      context 'when the entered OTP has lowercase' do
        let(:entered_otp) { 'abcdef12345' }
        let(:otp) { 'ABCDEF12345' }

        it 'is valid' do
          result = subject.submit
          expect(result.success?).to eq(true)
        end
      end

      context 'when the entered OTP has ohs instead of zeroes' do
        let(:entered_otp) { 'oOoOoOoOoO' }
        let(:otp) { '0000000000' }

        it 'is valid' do
          result = subject.submit
          expect(result.success?).to eq(true)
        end
      end
    end

    context 'when OTP does not match' do
      let(:entered_otp) { 'wrong' }

      it 'is invalid' do
        result = subject.submit
        expect(result.success?).to eq(false)
        expect(result.errors[:otp]).to eq [t('errors.messages.confirmation_code_incorrect')]
      end
    end

    context 'when OTP is expired' do
      let(:code_sent_at) { 11.days.ago }

      it 'is invalid' do
        result = subject.submit
        expect(result.success?).to eq(false)
        expect(subject.errors[:otp]).to eq [t('errors.messages.gpo_otp_expired')]
      end
    end
  end

  describe '#submit' do
    context 'correct OTP' do
      it 'returns true' do
        result = subject.submit
        expect(result.success?).to eq true
      end

      it 'activates the pending profile' do
        expect(pending_profile).to_not be_active

        subject.submit

        expect(pending_profile.reload).to be_active
      end

      context 'pending in person enrollment' do
        let(:proofing_components) {
          ProofingComponent.create(user: user, document_check: Idp::Constants::Vendors::USPS)
        }
        before do
          allow(IdentityConfig.store).to receive(:in_person_proofing_enabled).and_return(true)
        end

        it 'sets profile to pending in person verification' do
          subject.submit
          pending_profile.reload

          expect(pending_profile).not_to be_active
          expect(pending_profile.deactivation_reason).to eq('in_person_verification_pending')
        end

        it 'creates an in-person enrollment' do
          subject.submit

          enrollment = InPersonEnrollment.where(user_id: user.id).first
          expect(enrollment.status).to eq('pending')
          expect(enrollment.user_id).to eq(user.id)
          expect(enrollment.enrollment_code).to be_a(String)
        end
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
