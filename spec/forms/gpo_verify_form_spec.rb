require 'rails_helper'

RSpec.describe GpoVerifyForm, allowed_extra_analytics: [:*] do
  subject(:form) do
    GpoVerifyForm.new(user: user, pii: applicant, otp: entered_otp)
  end

  let(:user) { create(:user, :fully_registered) }
  let(:applicant) { Idp::Constants::MOCK_IDV_APPLICANT_WITH_PHONE }
  let(:entered_otp) { otp }
  let(:otp) { 'ABC123' }
  let(:code_sent_at) { Time.zone.now }
  let(:pending_profile) do
    create(
      :profile,
      :verify_by_mail_pending,
      user: user,
      proofing_components: proofing_components,
    )
  end
  let(:proofing_components) { nil }
  let(:is_enhanced_ipp) { false }

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
        result = subject.submit(is_enhanced_ipp)
        expect(result.success?).to eq(false)
        expect(result.errors[:otp]).to eq [t('errors.messages.blank')]
      end
    end

    context 'when there is no pending profile ' do
      let(:pending_profile) { nil }
      let(:user) { build_stubbed(:user) }

      it 'is invalid' do
        result = subject.submit(is_enhanced_ipp)
        expect(result.success?).to eq(false)
        expect(result.errors[:base]).to eq [t('errors.messages.no_pending_profile')]
      end
    end

    context 'OTP crockford normalizing' do
      context 'when the entered OTP has lowercase' do
        let(:entered_otp) { 'abcdef12345' }
        let(:otp) { 'ABCDEF12345' }

        it 'is valid' do
          result = subject.submit(is_enhanced_ipp)
          expect(result.success?).to eq(true)
        end
      end

      context 'when the entered OTP has ohs instead of zeroes' do
        let(:entered_otp) { 'oOoOoOoOoO' }
        let(:otp) { '0000000000' }

        it 'is valid' do
          result = subject.submit(is_enhanced_ipp)
          expect(result.success?).to eq(true)
        end
      end
    end

    context 'when OTP does not match' do
      let(:entered_otp) { 'wrong' }

      it 'is invalid' do
        result = subject.submit(is_enhanced_ipp)
        expect(result.success?).to eq(false)
        expect(result.errors[:otp]).to eq [t('errors.messages.confirmation_code_incorrect')]
      end
    end

    context 'when OTP is expired' do
      let(:expiration_days) { 10 }
      let(:code_sent_at) { (expiration_days + 1).days.ago }
      let(:minimum_wait_before_another_usps_letter_in_hours) { 0 }

      before do
        allow(IdentityConfig.store).to receive(:usps_confirmation_max_days).
          and_return(expiration_days)
        allow(IdentityConfig.store).to receive(:minimum_wait_before_another_usps_letter_in_hours).
          and_return(minimum_wait_before_another_usps_letter_in_hours)
      end

      it 'is invalid' do
        result = subject.submit(is_enhanced_ipp)
        expect(result.success?).to eq(false)
        expect(subject.errors[:otp]).to eq [t('errors.messages.gpo_otp_expired')]
      end

      context 'and the user cannot request another letter' do
        before do
          allow(subject).to receive(:user_can_request_another_letter?).and_return(false)
        end
        it 'is invalid and uses different messaging' do
          result = subject.submit(is_enhanced_ipp)
          expect(result.success?).to eq(false)
          expect(subject.errors[:otp]).to eq [
            t('errors.messages.gpo_otp_expired_and_cannot_request_another'),
          ]
        end
      end
    end
  end

  describe '#submit' do
    context 'correct OTP' do
      it 'returns true' do
        result = subject.submit(is_enhanced_ipp)
        expect(result.success?).to eq true
      end

      it 'activates the pending profile' do
        expect(pending_profile).to_not be_active

        subject.submit(is_enhanced_ipp)

        expect(pending_profile.reload).to be_active
      end

      it 'logs the date the code was sent at' do
        result = subject.submit(is_enhanced_ipp)

        confirmation_code = pending_profile.gpo_confirmation_codes.last
        expect(result.to_h[:enqueued_at]).to eq(confirmation_code.code_sent_at)
      end

      context 'establishing in person enrollment' do
        let!(:establishing_enrollment) do
          create(
            :in_person_enrollment,
            :establishing,
            profile: pending_profile,
            user: user,
          )
        end

        let(:proofing_components) do
          ProofingComponent.create(user: user, document_check: Idp::Constants::Vendors::USPS)
        end

        before do
          allow(IdentityConfig.store).to receive(:in_person_proofing_enabled).and_return(true)
        end

        it 'sets profile to pending in person verification' do
          subject.submit(is_enhanced_ipp)
          pending_profile.reload

          expect(pending_profile).not_to be_active
          expect(pending_profile.in_person_verification_pending?).to eq(true)
          expect(pending_profile.gpo_verification_pending?).to eq(false)
        end

        it 'updates establishing in-person enrollment to pending' do
          subject.submit(is_enhanced_ipp)

          establishing_enrollment.reload

          expect(establishing_enrollment.status).to eq(InPersonEnrollment::STATUS_PENDING)
          expect(establishing_enrollment.user_id).to eq(user.id)
          expect(establishing_enrollment.enrollment_code).to be_a(String)
        end
      end

      context 'pending in person enrollment' do
        let!(:pending_enrollment) do
          create(
            :in_person_enrollment,
            :pending,
            profile: pending_profile,
            user: user,
          )
        end

        let(:proofing_components) do
          ProofingComponent.create(user: user, document_check: Idp::Constants::Vendors::USPS)
        end

        before do
          allow(IdentityConfig.store).to receive(:in_person_proofing_enabled).and_return(true)
        end

        it 'changes profile from pending to active' do
          subject.submit(is_enhanced_ipp)
          pending_profile.reload

          expect(pending_profile).to be_active
          expect(pending_profile.deactivation_reason).to be_nil
          expect(pending_profile.in_person_verification_pending_at).to be_nil
          expect(pending_profile.gpo_verification_pending?).to eq(false)
        end
      end

      context 'ThreatMetrix rejection' do
        let(:pending_profile) do
          create(:profile, :verify_by_mail_pending, :fraud_pending_reason, user: user)
        end

        before do
          allow(IdentityConfig.store).to receive(:proofing_device_profiling).and_return(:enabled)
        end

        it 'returns true' do
          result = subject.submit(is_enhanced_ipp)
          expect(result.success?).to eq true
        end

        it 'does not activate the users profile' do
          subject.submit(is_enhanced_ipp)
          profile = user.profiles.first
          expect(profile.active).to eq(false)
          expect(profile.fraud_review_pending?).to eq(true)
        end

        it 'notes that threatmetrix failed' do
          result = subject.submit(is_enhanced_ipp)
          expect(result.extra).to include(fraud_check_failed: true)
        end

        context 'threatmetrix is not required for verification' do
          before do
            allow(IdentityConfig.store).to receive(:proofing_device_profiling).and_return(:disabled)
          end

          it 'returns true' do
            result = subject.submit(is_enhanced_ipp)
            expect(result.success?).to eq true
          end

          it 'does activate the users profile' do
            subject.submit(is_enhanced_ipp)
            profile = user.profiles.first
            expect(profile.active).to eq(true)
            expect(profile.deactivation_reason).to eq(nil)
          end

          it 'notes that threatmetrix failed' do
            result = subject.submit(is_enhanced_ipp)
            expect(result.extra).to include(fraud_check_failed: true)
          end
        end
      end
    end

    context 'incorrect OTP' do
      let(:entered_otp) { 'wrong' }

      it 'clears form' do
        subject.submit(is_enhanced_ipp)

        expect(subject.otp).to be_nil
      end
    end

    describe '#which_letter with three letters sent' do
      let(:first_otp) { 'F' + otp }
      let(:second_otp) { 'S' + otp }
      let(:third_otp) { otp }

      before do
        create(
          :gpo_confirmation_code,
          otp_fingerprint: Pii::Fingerprinter.fingerprint(first_otp),
          code_sent_at: code_sent_at - 5.days,
          profile: pending_profile,
        )

        create(
          :gpo_confirmation_code,
          otp_fingerprint: Pii::Fingerprinter.fingerprint(second_otp),
          code_sent_at: code_sent_at - 3.days,
          profile: pending_profile,
        )
      end

      context 'entered first code' do
        let(:entered_otp) { first_otp }

        it 'logs which letter and letter count' do
          result = subject.submit(is_enhanced_ipp)

          expect(result.to_h[:which_letter]).to eq(1)
          expect(result.to_h[:letter_count]).to eq(3)
        end
      end

      context 'entered second code' do
        let(:entered_otp) { second_otp }

        it 'logs which letter and letter count' do
          result = subject.submit(is_enhanced_ipp)

          expect(result.to_h[:which_letter]).to eq(2)
          expect(result.to_h[:letter_count]).to eq(3)
        end
      end

      context 'entered third code' do
        let(:entered_code) { third_otp }

        it 'logs which letter and letter count' do
          result = subject.submit(is_enhanced_ipp)

          expect(result.to_h[:which_letter]).to eq(3)
          expect(result.to_h[:letter_count]).to eq(3)
        end
      end
    end

    context 'when the user is going through enhanced ipp' do
      let(:is_enhanced_ipp) { true }
      let!(:establishing_enrollment) do
        create(
          :in_person_enrollment,
          :establishing,
          profile: pending_profile,
          user: user,
        )
      end
      it 'sends the correct information for scheduling an in person enrollment' do
        expect(UspsInPersonProofing::EnrollmentHelper).to receive(:schedule_in_person_enrollment).
          with(user: anything, pii: anything, is_enhanced_ipp: is_enhanced_ipp)

        subject.submit(is_enhanced_ipp)
      end
    end
  end
end
