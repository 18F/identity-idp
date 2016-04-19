describe Authorization do
  subject { build(:authorization, user: create(:user)) }

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

  context 'user.uuid is same as uid' do
    it 'does not update the user uuid' do
      user = create(:user, :signed_up)
      user.update!(uuid: '33ad9eca-76de-4ed5-b3b4-eae34efe16e3')
      auth = build(:authorization, user: user)
      expect(auth).to_not receive(:update_user_uuid)
      auth.save
    end
  end

  context 'user.uuid is not the same as uid' do
    it 'updates the user uuid' do
      user = create(:user, :signed_up)
      auth = build(:authorization, user: user)
      expect(auth).to receive(:update_user_uuid)
      auth.save
    end
  end

  context 'user role is tech' do
    it 'does not update the user role' do
      user = create(:user, :signed_up, role: :tech)
      auth = build(:authorization, user: user)
      expect(auth).to_not receive(:update_user_role)
      auth.save
    end
  end
end
