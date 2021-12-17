require 'rails_helper'

describe Idv::ProfileMaker do
  let(:applicant) { { first_name: 'Some', last_name: 'One' } }
  let(:user) { create(:user, :signed_up) }
  let(:user_password) { user.password }
  let(:document_expired) { nil }

  subject(:profile_maker) do
    described_class.new(
      applicant: applicant,
      user: user,
      user_password: user_password,
      document_expired: document_expired,
    )
  end

  describe '#save_profile' do
    it 'creates a Profile with encrypted PII' do
      proofing_component = ProofingComponent.create(user_id: user.id, document_check: 'acuant')
      profile = profile_maker.save_profile
      pii = profile_maker.pii_attributes

      expect(profile).to be_a Profile
      expect(profile.id).to_not be_nil
      expect(profile.encrypted_pii).to_not be_nil
      expect(profile.encrypted_pii).to_not match 'Some'
      expect(profile.proofing_components).to match proofing_component.as_json
      expect(profile.reproof_at).to be_nil

      expect(pii).to be_a Pii::Attributes
      expect(pii.first_name).to eq 'Some'
    end

    context 'with an expired doucument' do
      let(:document_expired) { true }

      it 'saves the profile.reproof_at' do
        profile = profile_maker.save_profile

        expect(profile.reproof_at).to eq(IdentityConfig.store.proofing_expired_license_reproof_at)
      end
    end
  end
end
