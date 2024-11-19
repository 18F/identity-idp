require 'rails_helper'

RSpec.describe Idv::ProfileMaker do
  describe '#save_profile' do
    let(:applicant) { { first_name: 'Some', last_name: 'One' } }
    let(:user) { create(:user, :fully_registered) }
    let(:user_password) { user.password }
    let(:initiating_service_provider) { nil }
    let(:in_person_proofing_enforce_tmx_mock) { false }
    let(:proofing_components) { { document_check: :mock } }

    subject do
      described_class.new(
        applicant: applicant,
        user: user,
        user_password: user_password,
        initiating_service_provider: initiating_service_provider,
      )
    end

    it 'creates an inactive Profile with encrypted PII' do
      profile = subject.save_profile(
        fraud_pending_reason: nil,
        gpo_verification_needed: false,
        in_person_verification_needed: false,
        selfie_check_performed: false,
        proofing_components:,
      )
      pii = subject.pii_attributes

      expect(profile).to be_a Profile
      expect(profile.id).to_not be_nil
      expect(profile.encrypted_pii).to_not be_nil
      expect(profile.encrypted_pii).to_not match('Some')
      expect(profile.fraud_pending_reason).to be_nil
      expect(profile.proofing_components).to match(proofing_components.to_json)
      expect(profile.active).to eq(false)
      expect(profile.deactivation_reason).to be_nil

      expect(pii).to be_a Pii::Attributes
      expect(pii.first_name).to eq('Some')
    end

    context 'with deactivation reason' do
      let(:profile) do
        subject.save_profile(
          fraud_pending_reason: nil,
          gpo_verification_needed: false,
          deactivation_reason: :encryption_error,
          in_person_verification_needed: false,
          selfie_check_performed: false,
          proofing_components:,
        )
      end
      it 'creates an inactive profile with deactivation reason' do
        expect(profile.activated_at).to be_nil
        expect(profile.active).to eq(false)
        expect(profile.deactivation_reason).to eq('encryption_error')
        expect(profile.fraud_pending_reason).to be_nil
        expect(profile.fraud_review_pending?).to eq(false)
        expect(profile.gpo_verification_pending_at.present?).to eq(false)
        expect(profile.initiating_service_provider).to eq(nil)
        expect(profile.verified_at).to be_nil
      end
      it 'marks the profile as legacy_unsupervised' do
        expect(profile.idv_level).to eql('legacy_unsupervised')
      end
    end

    context 'with fraud review needed' do
      let(:gpo_verification_needed) { false }
      let(:in_person_verification_needed) { false }
      let(:profile) do
        subject.save_profile(
          fraud_pending_reason: 'threatmetrix_review',
          gpo_verification_needed: gpo_verification_needed,
          deactivation_reason: nil,
          in_person_verification_needed: in_person_verification_needed,
          selfie_check_performed: false,
          proofing_components:,
        )
      end

      it 'creates a pending profile for fraud review' do
        expect(profile.activated_at).to be_nil
        expect(profile.active).to eq(false)
        expect(profile.deactivation_reason).to be_nil
        expect(profile.fraud_pending_reason).to eq('threatmetrix_review')
        expect(profile.fraud_review_pending?).to eq(true)
        expect(profile.gpo_verification_pending_at.present?).to eq(false)
        expect(profile.initiating_service_provider).to eq(nil)
        expect(profile.verified_at).to be_nil
      end

      it 'marks the profile as legacy_unsupervised' do
        expect(profile.idv_level).to eql('legacy_unsupervised')
      end

      context 'when GPO verification is needed' do
        let(:gpo_verification_needed) { true }

        it 'is not fraud_review_pending?' do
          expect(profile.fraud_review_pending?).to eq(false)
        end
      end

      context 'when IPP is needed' do
        let(:in_person_verification_needed) { true }

        it 'is not fraud_review_pending?' do
          expect(profile.fraud_review_pending?).to eq(false)
        end
      end
    end

    context 'with gpo_verification_needed' do
      let(:profile) do
        subject.save_profile(
          fraud_pending_reason: nil,
          gpo_verification_needed: true,
          deactivation_reason: nil,
          in_person_verification_needed: false,
          selfie_check_performed: false,
          proofing_components:,
        )
      end
      it 'creates a pending profile for gpo verification' do
        expect(profile.activated_at).to be_nil
        expect(profile.active).to eq(false)
        expect(profile.deactivation_reason).to be_nil
        expect(profile.fraud_pending_reason).to be_nil
        expect(profile.fraud_review_pending?).to eq(false)
        expect(profile.gpo_verification_pending_at.present?).to eq(true)
        expect(profile.initiating_service_provider).to eq(nil)
        expect(profile.verified_at).to be_nil
      end
      it 'marks the profile as legacy_unsupervised' do
        expect(profile.idv_level).to eql('legacy_unsupervised')
      end
    end

    context 'with in_person_verification_needed' do
      context 'when threatmetrix decisioning is disabled' do
        before do
          allow(IdentityConfig.store).to receive(:in_person_proofing_enforce_tmx).
            and_return(in_person_proofing_enforce_tmx_mock)
          allow(IdentityConfig.store).to receive(:proofing_device_profiling).
            and_return(:disabled)
        end

        let(:profile) do
          subject.save_profile(
            fraud_pending_reason: nil,
            gpo_verification_needed: false,
            deactivation_reason: nil,
            in_person_verification_needed: true,
            selfie_check_performed: false,
            proofing_components:,
          )
        end

        it 'creates a pending profile for in person verification' do
          expect(profile.activated_at).to be_nil
          expect(profile.active).to eq(false)
          expect(profile.deactivation_reason).to be_nil
          expect(profile.fraud_pending_reason).to be_nil
          expect(profile.in_person_verification_pending?).to eq(true)
          expect(profile.fraud_review_pending?).to eq(false)
          expect(profile.gpo_verification_pending_at.present?).to eq(false)
          expect(profile.initiating_service_provider).to eq(nil)
          expect(profile.verified_at).to be_nil
        end

        it 'marks the profile as legacy_in_person' do
          expect(profile.idv_level).to eql('legacy_in_person')
        end
      end
    end

    context 'with in_person_verification_needed' do
      context 'when threatmetrix decisioning is enabled' do
        let(:in_person_proofing_enforce_tmx_mock) { true }

        before do
          allow(IdentityConfig.store).to receive(:in_person_proofing_enforce_tmx).
            and_return(in_person_proofing_enforce_tmx_mock)
          allow(IdentityConfig.store).to receive(:proofing_device_profiling).
            and_return(:enabled)
        end

        let(:profile) do
          subject.save_profile(
            fraud_pending_reason: nil,
            gpo_verification_needed: false,
            deactivation_reason: nil,
            in_person_verification_needed: true,
            selfie_check_performed: false,
            proofing_components:,
          )
        end

        it 'creates a pending profile for in person verification' do
          expect(profile.activated_at).to be_nil
          expect(profile.active).to eq(false)
          expect(profile.deactivation_reason).to be_nil
          expect(profile.fraud_pending_reason).to be_nil
          expect(profile.in_person_verification_pending?).to eq(true)
          expect(profile.fraud_review_pending?).to eq(false)
          expect(profile.gpo_verification_pending_at.present?).to eq(false)
          expect(profile.initiating_service_provider).to eq(nil)
          expect(profile.verified_at).to be_nil
        end

        it 'marks the profile as in_person' do
          expect(profile.idv_level).to eql('in_person')
        end
      end
    end

    context 'as active' do
      let(:selfie_check_performed) { false }
      let(:profile) do
        subject.save_profile(
          fraud_pending_reason: nil,
          gpo_verification_needed: false,
          deactivation_reason: nil,
          in_person_verification_needed: false,
          selfie_check_performed: selfie_check_performed,
          proofing_components:,
        )
      end

      context 'legacy unsupervised' do
        it 'creates an active profile' do
          expect(profile.activated_at).to be_nil
          expect(profile.active).to eq(false)
          expect(profile.deactivation_reason).to be_nil
          expect(profile.fraud_pending_reason).to be_nil
          expect(profile.fraud_review_pending?).to eq(false)
          expect(profile.gpo_verification_pending_at.present?).to eq(false)
          expect(profile.initiating_service_provider).to eq(nil)
          expect(profile.verified_at).to be_nil
        end
        it 'marks the profile as legacy_unsupervised' do
          expect(profile.idv_level).to eql('legacy_unsupervised')
        end
      end

      context 'unsupervised with selfie' do
        let(:selfie_check_performed) { true }

        it 'creates an active profile' do
          expect(profile.activated_at).to be_nil
          expect(profile.active).to eq(false)
          expect(profile.deactivation_reason).to be_nil
          expect(profile.fraud_pending_reason).to be_nil
          expect(profile.fraud_review_pending?).to eq(false)
          expect(profile.gpo_verification_pending_at.present?).to eq(false)
          expect(profile.initiating_service_provider).to eq(nil)
          expect(profile.verified_at).to be_nil
        end
        it 'marks the profile as unsupervised_with_selfie' do
          expect(profile.idv_level).to eql('unsupervised_with_selfie')
        end
      end
    end

    context 'with an initiating service provider' do
      let(:initiating_service_provider) { create(:service_provider) }
      let(:profile) do
        subject.save_profile(
          fraud_pending_reason: nil,
          gpo_verification_needed: false,
          deactivation_reason: nil,
          in_person_verification_needed: false,
          selfie_check_performed: false,
          proofing_components:,
        )
      end
      it 'creates a profile with the initiating sp recorded' do
        expect(profile.activated_at).to be_nil
        expect(profile.active).to eq(false)
        expect(profile.deactivation_reason).to be_nil
        expect(profile.fraud_pending_reason).to be_nil
        expect(profile.fraud_review_pending?).to eq(false)
        expect(profile.gpo_verification_pending_at.present?).to eq(false)
        expect(profile.initiating_service_provider).to eq(initiating_service_provider)
        expect(profile.verified_at).to be_nil
      end
      it 'marks the profile as legacy_unsupervised' do
        expect(profile.idv_level).to eql('legacy_unsupervised')
      end
    end
  end
end
