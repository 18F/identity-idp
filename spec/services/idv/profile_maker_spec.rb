require 'rails_helper'

describe Idv::ProfileMaker do
  let(:applicant) { { first_name: 'Some', last_name: 'One' } }
  let(:user) { create(:user, :signed_up) }
  let(:user_password) { user.password }
  let(:reproof_at) { nil }

  subject(:profile_maker) do
    described_class.new(
      applicant: applicant,
      user: user,
      user_password: user_password,
      reproof_at: reproof_at,
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
      expect(profile.proofing_components).to match proofing_component.to_json
      expect(profile.reproof_at).to be_nil

      expect(pii).to be_a Pii::Attributes
      expect(pii.first_name).to eq 'Some'
    end

    context 'with a reproof_at date' do
      let(:reproof_at) { Date.new(2025, 1, 1) }

      it 'saves the profile.reproof_at' do
        profile = profile_maker.save_profile

        expect(profile.reproof_at.to_date).to eq(reproof_at)
      end
    end
  end
end
