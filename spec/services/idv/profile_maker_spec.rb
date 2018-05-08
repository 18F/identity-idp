require 'rails_helper'

describe Idv::ProfileMaker do
  describe '#save_profile' do
    it 'creates Profile with encrypted PII' do
      applicant = { first_name: 'Some', last_name: 'One' }
      normalized_applicant = { first_name: 'Somebody', last_name: 'Oneatatime' }
      user = create(:user, :signed_up)
      user.unlock_user_access_key(user.password)

      profile_maker = described_class.new(
        applicant: applicant,
        user: user,
        normalized_applicant: normalized_applicant,
        phone_confirmed: false
      )

      profile = profile_maker.save_profile
      pii = profile_maker.pii_attributes

      expect(profile).to be_a Profile
      expect(profile.id).to_not be_nil
      expect(profile.encrypted_pii).to_not be_nil
      expect(profile.encrypted_pii).to_not match 'Some'

      expect(pii).to be_a Pii::Attributes
      expect(pii.first_name.raw).to eq 'Some'
      expect(pii.first_name.norm).to eq 'Somebody'
    end
  end
end
