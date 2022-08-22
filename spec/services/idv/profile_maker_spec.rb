require 'rails_helper'

describe Idv::ProfileMaker do
  describe '#save_profile' do
    let(:applicant) { { first_name: 'Some', last_name: 'One' } }
    let(:user) { create(:user, :signed_up) }
    let(:user_password) { user.password }

    subject do
      described_class.new(
        applicant: applicant,
        user: user,
        user_password: user_password,
      )
    end

    it 'creates an inactive Profile with encrypted PII' do
      proofing_component = ProofingComponent.create(user_id: user.id, document_check: 'acuant')
      profile = subject.save_profile(active: false)
      pii = subject.pii_attributes

      expect(profile).to be_a Profile
      expect(profile.id).to_not be_nil
      expect(profile.encrypted_pii).to_not be_nil
      expect(profile.encrypted_pii).to_not match 'Some'
      expect(profile.proofing_components).to match proofing_component.as_json
      expect(profile.active).to eq false
      expect(profile.deactivation_reason).to be_nil

      expect(pii).to be_a Pii::Attributes
      expect(pii.first_name).to eq 'Some'
      expect(profile.reproof_at).to be_nil
    end

    context 'with deactivation reason' do
      it 'creates an inactive profile with deactivation reason' do
        profile = subject.save_profile(
          active: false,
          deactivation_reason: :gpo_verification_pending,
        )

        expect(profile.active).to eq false
        expect(profile.deactivation_reason).to eq 'gpo_verification_pending'
      end
    end

    context 'as active' do
      it 'creates an active profile' do
        profile = subject.save_profile(active: true, deactivation_reason: nil)

        expect(profile.active).to eq true
        expect(profile.deactivation_reason).to be_nil
      end
    end
  end
end
