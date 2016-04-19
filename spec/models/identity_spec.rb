describe Identity do
  let(:user) { create(:user, :signed_up) }
  let(:identity) do
    Identity.create(
      user_id: user.id,
      service_provider: 'externalapp'
    )
  end
  subject { identity }

  it { is_expected.to belong_to(:user) }

  it { is_expected.to validate_presence_of(:service_provider) }

  it 'has a session uuid' do
    expect(subject.session_uuid).to_not be_nil
  end

  describe '.deactivate!' do
    let(:active_identity) { create(:identity, :active) }

    it 'sets last_authenticated_at to nil' do
      active_identity.deactivate!
      expect(identity.last_authenticated_at).to be_nil
    end
  end
end
