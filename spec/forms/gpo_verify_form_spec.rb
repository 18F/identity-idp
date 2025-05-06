require 'rails_helper'

RSpec.describe GpoVerifyForm do
  subject(:form) do
    GpoVerifyForm.new(
      attempts_api_tracker:,
      user:,
      pii: applicant,
      resolved_authn_context_result: Vot::Parser::Result.no_sp_result,
      otp: entered_otp,
    )
  end

  let(:attempts_api_tracker) { AttemptsApiTrackingHelper::FakeAttemptsTracker.new }
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
      let(:expiration_days) { 10 }
      let(:code_sent_at) { (expiration_days + 1).days.ago }
      let(:minimum_wait_before_another_usps_letter_in_hours) { 0 }

      before do
        allow(IdentityConfig.store).to receive(:usps_confirmation_max_days)
          .and_return(expiration_days)
        allow(IdentityConfig.store).to receive(:minimum_wait_before_another_usps_letter_in_hours)
          .and_return(minimum_wait_before_another_usps_letter_in_hours)
      end

      it 'is invalid' do
        result = subject.submit
        expect(result.success?).to eq(false)
        expect(subject.errors[:otp]).to eq [t('errors.messages.gpo_otp_expired')]
      end

      context 'and the user cannot request another letter' do
        before do
          allow(subject).to receive(:user_can_request_another_letter?).and_return(false)
        end
        it 'is invalid and uses different messaging' do
          result = subject.submit
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
      context 'ThreatMetrix rejection' do
        let(:pending_profile) do
          create(:profile, :verify_by_mail_pending, :fraud_pending_reason, user: user)
        end

        before do
          allow(IdentityConfig.store).to receive(:proofing_device_profiling).and_return(:enabled)
        end

        it 'returns true' do
          result = subject.submit
          expect(result.success?).to eq true
        end

        it 'does not activate the users profile' do
          subject.submit
          profile = user.profiles.first
          expect(profile.active).to eq(false)
          expect(profile.fraud_review_pending?).to eq(true)
        end

        it 'notes that threatmetrix failed' do
          result = subject.submit
          expect(result.extra).to include(fraud_check_failed: true)
        end

        it 'does not track an enrollment event' do
          expect(attempts_api_tracker).not_to receive(:idv_enrollment_complete)
          subject.submit
        end

        context 'threatmetrix is not required for verification' do
          before do
            allow(IdentityConfig.store).to receive(:proofing_device_profiling).and_return(:disabled)
          end

          it 'returns true' do
            result = subject.submit
            expect(result.success?).to eq true
          end

          it 'does activate the users profile' do
            subject.submit
            profile = user.profiles.first
            expect(profile.active).to eq(true)
            expect(profile.deactivation_reason).to eq(nil)
          end

          it 'notes that threatmetrix failed' do
            result = subject.submit
            expect(result.extra).to include(fraud_check_failed: true)
          end

          it 'tracks an enrollment event' do
            expect(attempts_api_tracker).to receive(:idv_enrollment_complete).with(reproof: false)
            subject.submit
          end

          context 'the user has proofed before' do
            before { create(:profile, :deactivated, user:) }

            it 'tracks an enrollment event with reproof set to true' do
              expect(attempts_api_tracker).to receive(:idv_enrollment_complete).with(reproof: true)
              subject.submit
            end
          end
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
          result = subject.submit

          expect(result.to_h[:which_letter]).to eq(1)
          expect(result.to_h[:letter_count]).to eq(3)
        end

        it 'tracks an enrollment event' do
          expect(attempts_api_tracker).to receive(:idv_enrollment_complete).with(reproof: false)
          subject.submit
        end
      end

      context 'entered second code' do
        let(:entered_otp) { second_otp }

        it 'logs which letter and letter count' do
          result = subject.submit

          expect(result.to_h[:which_letter]).to eq(2)
          expect(result.to_h[:letter_count]).to eq(3)
        end

        it 'tracks an enrollment event' do
          expect(attempts_api_tracker).to receive(:idv_enrollment_complete).with(reproof: false)
          subject.submit
        end
      end

      context 'entered third code' do
        let(:entered_code) { third_otp }

        it 'logs which letter and letter count' do
          result = subject.submit

          expect(result.to_h[:which_letter]).to eq(3)
          expect(result.to_h[:letter_count]).to eq(3)
        end

        it 'tracks an enrollment event' do
          expect(attempts_api_tracker).to receive(:idv_enrollment_complete).with(reproof: false)
          subject.submit
        end
      end
    end
  end
end
