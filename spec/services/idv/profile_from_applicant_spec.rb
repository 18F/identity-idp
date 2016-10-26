require 'rails_helper'

describe Idv::ProfileFromApplicant do
  describe '#create' do
    it 'creates Profile with encrypted PII' do
      applicant = Proofer::Applicant.new first_name: 'Some', last_name: 'One'
      user = create(:user, :signed_up)
      password = 'sekrit'
      profile = described_class.create(applicant, user, password)

      expect(profile.id).to_not be_nil
      expect(profile.encrypted_pii).to_not be_nil
      expect(profile.encrypted_pii).to_not match 'Some'
    end
  end
end
