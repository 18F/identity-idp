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
    it 'creates a Profile with encrypted PII' do
      proofing_component = ProofingComponent.create(user_id: user.id, document_check: 'acuant')
      profile = subject.save_profile
      pii = subject.pii_attributes

      expect(profile).to be_a Profile
      expect(profile.id).to_not be_nil
      expect(profile.encrypted_pii).to_not be_nil
      expect(profile.encrypted_pii).to_not match 'Some'
      expect(profile.proofing_components).to match proofing_component.as_json

      expect(pii).to be_a Pii::Attributes
      expect(pii.first_name).to eq 'Some'
      expect(profile.reproof_at).to be_nil
    end
  end
end
