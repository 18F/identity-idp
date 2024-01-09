require 'rails_helper'

RSpec.describe Idv::ProfileMaker do
  describe '#save_profile' do
    let(:applicant) { { first_name: 'Some', last_name: 'One' } }
    let(:user) { create(:user, :fully_registered) }
    let(:user_password) { user.password }
    let(:initiating_service_provider) { nil }

    subject do
      described_class.new(
        applicant: applicant,
        user: user,
        user_password: user_password,
        initiating_service_provider: initiating_service_provider,
      )
    end

    it 'creates an inactive Profile with encrypted PII' do
      proofing_component = ProofingComponent.create(user_id: user.id, document_check: 'acuant')
      profile = subject.save_profile(
        fraud_pending_reason: nil,
        gpo_verification_needed: false,
        in_person_verification_needed: false,
      )
      pii = subject.pii_attributes

      expect(profile).to be_a Profile
      expect(profile.id).to_not be_nil
      expect(profile.encrypted_pii).to_not be_nil
      expect(profile.encrypted_pii).to_not match('Some')
      expect(profile.fraud_pending_reason).to be_nil
      expect(profile.proofing_components).to match(proofing_component.as_json)
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
      let(:profile) do
        subject.save_profile(
          fraud_pending_reason: 'threatmetrix_review',
          gpo_verification_needed: false,
          deactivation_reason: nil,
          in_person_verification_needed: false,
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
    end

    context 'with gpo_verification_needed' do
      let(:profile) do
        subject.save_profile(
          fraud_pending_reason: nil,
          gpo_verification_needed: true,
          deactivation_reason: nil,
          in_person_verification_needed: false,
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
      let(:profile) do
        subject.save_profile(
          fraud_pending_reason: nil,
          gpo_verification_needed: false,
          deactivation_reason: nil,
          in_person_verification_needed: true,
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

    context 'as active' do
      let(:profile) do
        subject.save_profile(
          fraud_pending_reason: nil,
          gpo_verification_needed: false,
          deactivation_reason: nil,
          in_person_verification_needed: false,
        )
      end
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

    context 'with an initiating service provider' do
      let(:initiating_service_provider) { create(:service_provider) }
      let(:profile) do
        subject.save_profile(
          fraud_pending_reason: nil,
          gpo_verification_needed: false,
          deactivation_reason: nil,
          in_person_verification_needed: false,
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
