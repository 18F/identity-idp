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
      profile = subject.save_profile
      pii = subject.pii_attributes

      expect(profile).to be_a Profile
      expect(profile.id).to_not be_nil
      expect(profile.encrypted_pii).to_not be_nil
      expect(profile.encrypted_pii).to_not match 'Some'

      expect(pii).to be_a Pii::Attributes
      expect(pii.first_name).to eq 'Some'
    end
  end
end
