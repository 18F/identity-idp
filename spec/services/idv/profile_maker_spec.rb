require 'rails_helper'

describe Idv::ProfileMaker do
  describe '#save_profile' do
    let(:applicant) { { first_name: 'Some', last_name: 'One' } }
    let(:normalized_applicant) { { first_name: 'Somebody', last_name: 'Oneatatime' } }
    let(:user) { create(:user, :signed_up) }
    let(:user_password) { user.password }
    let(:phone_confirmed) { false }

    subject do
      described_class.new(
        applicant: applicant,
        normalized_applicant: normalized_applicant,
        user: user,
        user_password: user_password,
        phone_confirmed: phone_confirmed
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
      expect(pii.first_name.raw).to eq 'Some'
      expect(pii.first_name.norm).to eq 'Somebody'
    end

    context 'when phone_confirmed is true' do
      let(:phone_confirmed) { true }
      it { expect(subject.save_profile.phone_confirmed).to eq(true) }
    end

    context 'when phone_confirmed is false' do
      let(:phone_confirmed) { false }
      it { expect(subject.save_profile.phone_confirmed).to eq(false) }
    end
  end
end
