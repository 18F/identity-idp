require 'rails_helper'

describe Authorization do
  subject { build(:authorization) }

  it { is_expected.to belong_to(:user) }

  it { is_expected.to validate_presence_of(:user_id) }
  it { is_expected.to validate_presence_of(:uid) }
  it { is_expected.to validate_presence_of(:provider) }

  it { is_expected.to validate_uniqueness_of(:uid).scoped_to(:provider).case_insensitive }

  it { is_expected.to be_valid }

  context 'valid attributes' do
    let(:user) { create(:user, :signed_up) }
    subject { build(:authorization, uid: SecureRandom.uuid, user_id: user.id) }
    it { is_expected.to be_valid }
  end

  context 'uid is not the same as user.uuid or identity UUIDs' do
    it 'does not update the user uuid' do
      user = create(:user, :signed_up)
      auth = build(:authorization, user: user)
      auth.save
      user.save
      expect(auth.uid).to_not eq(user.uuid)
      expect(user.identities.map(&:uuid)).to_not include(auth.uid)
    end
  end
end
