require 'rails_helper'

describe Authorization do
  subject { build(:authorization) }

  it { is_expected.to belong_to(:user) }

  it { is_expected.to validate_presence_of(:user_id) }
  it { is_expected.to validate_presence_of(:uid) }
  it { is_expected.to validate_presence_of(:provider) }

  it { is_expected.to validate_uniqueness_of(:uid).scoped_to(:provider) }

  it { is_expected.to be_valid }

  context 'valid attributes' do
    let(:user) { create(:user, :signed_up) }
    subject { build(:authorization, uid: user.uuid, user_id: user.id) }
    it { is_expected.to be_valid }
  end

  context 'user.uuid is not the same as uid' do
    it 'does not update the user uuid' do
      user = create(:user, :signed_up)
      auth = build(:authorization, user: user)
      auth.save
      user.save
      expect(auth.uid).to_not eq(user.uuid)
    end
  end
end
