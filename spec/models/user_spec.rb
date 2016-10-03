require 'rails_helper'
require 'saml_idp_constants'

MAX_GOOD_PASSWORD = '!1aZ' * 32

describe User do
  describe 'Associations' do
    it { is_expected.to have_many(:authorizations) }
    it { is_expected.to have_many(:identities) }
    it { is_expected.to have_many(:profiles) }
    it { is_expected.to have_many(:events) }
  end

  it 'should only send one email during creation' do
    expect do
      User.create(email: 'nobody@nobody.com')
    end.to change(ActionMailer::Base.deliveries, :count).by(1)
  end

  describe 'uuid validations' do
    it 'uses a DB constraint to enforce presence' do
      user = create(:user)
      user.uuid = nil

      expect { user.save }.
        to raise_error(ActiveRecord::StatementInvalid,
                       /null value in column "uuid" violates not-null constraint/)
    end

    it 'uses a DB index to enforce uniqueness' do
      user1 = create(:user)
      user1.save
      user2 = create(:user, email: "mkuniqu.#{user1.email}")
      user2.uuid = user1.uuid

      expect { user2.save }.
        to raise_error(ActiveRecord::StatementInvalid,
                       /duplicate key value violates unique constraint/)
    end
  end

  describe '#generate_uuid' do
    it 'calls generate_uuid before creation' do
      user = build(:user, uuid: 'foo')

      expect(user).to receive(:generate_uuid)

      user.save
    end

    context 'when the user already has a uuid' do
      it 'returns the current uuid' do
        user = create(:user)
        old_uuid = user.uuid

        expect(user.generate_uuid).to eq old_uuid
      end
    end

    context 'when the user does not already have a uuid' do
      it 'generates it via SecureRandom.uuid' do
        user = build(:user)

        expect(user.generate_uuid).
          to match(/[a-f0-9]{8}-[a-f0-9]{4}-4[a-f0-9]{3}-[89aAbB][a-f0-9]{3}-[a-f0-9]{12}/)
      end
    end
  end

  context '#two_factor_enabled?' do
    it 'is true when user has a confirmed phone' do
      user = create(:user, :with_phone)

      expect(user.two_factor_enabled?).to eq true
    end

    it 'is false when user does not have a phone' do
      user = create(:user)

      expect(user.two_factor_enabled?).to eq false
    end
  end

  context '#need_two_factor_authentication?' do
    let(:request) { ActionController::TestRequest.new }

    it 'is true when two_factor_enabled' do
      user = build_stubbed(:user)

      allow(user).to receive(:two_factor_enabled?).and_return true

      expect(user.need_two_factor_authentication?(nil)).to be_truthy
    end

    it 'is false when not two_factor_enabled' do
      user = build_stubbed(:user)

      allow(user).to receive(:two_factor_enabled?).and_return false

      expect(user.need_two_factor_authentication?(nil)).to be_falsey
    end
  end

  context '#confirmation_period_expired?' do
    it 'returns false when within confirm_within value' do
      user = create(:user, confirmed_at: nil)
      user.confirmation_sent_at = Time.current - User.confirm_within + 1.minute
      user.save
      expect(user.confirmation_period_expired?).to be_falsey
    end

    it 'returns true when beyond confirm_within value' do
      user = create(:user, confirmed_at: nil)
      user.confirmation_sent_at = Time.current - User.confirm_within - 1.minute
      user.save
      expect(user.confirmation_period_expired?).to be_truthy
    end
  end

  context 'when identities are present' do
    let(:user) { create(:user, :signed_up) }
    let(:active_identity) do
      Identity.create(service_provider: 'entity_id', session_uuid: SecureRandom.uuid)
    end
    let(:inactive_identity) do
      Identity.create(service_provider: 'entity_id', session_uuid: nil)
    end

    describe '#active_identities' do
      before { user.identities << [active_identity, inactive_identity] }

      it 'only returns active identities' do
        expect(user.active_identities.size).to eq(1)
      end
    end
  end

  context 'when user has multiple identities' do
    let(:user) { create(:user, :signed_up) }

    before do
      user.identities << Identity.create(
        service_provider: 'first',
        last_authenticated_at: Time.current - 1.hour,
        session_uuid: SecureRandom.uuid
      )
      user.identities << Identity.create(
        service_provider: 'last',
        last_authenticated_at: Time.current,
        session_uuid: SecureRandom.uuid
      )
    end

    describe '#last_identity' do
      it 'returns the most recently authenticated identity' do
        expect(user.last_identity.service_provider).to eq('last')
      end
    end

    describe '#first_identity' do
      it 'returns the first authenticated identity' do
        expect(user.first_identity.service_provider).to eq('first')
      end
    end
  end

  context 'when user has multiple profiles' do
    let(:user) { create(:user, :signed_up) }
    let(:profile1) { build(:profile, :active, :verified, first_name: 'Jane', user: user) }
    let(:profile2) { build(:profile, :verified, first_name: 'Susan', user: user) }

    before do
      profile1.save!
      profile2.save!
    end

    describe '#active_profile' do
      it 'returns the only active profile' do
        expect(user.active_profile).to eq profile1
      end
    end
  end

  describe 'OTP length' do
    it 'uses Devise setting when set' do
      allow(Devise).to receive(:direct_otp_length).and_return(10)
      user = build(:user)
      user.send_new_otp

      expect(user.direct_otp.length).to eq 10
    end

    it 'defaults to 6 when Devise setting is not set' do
      allow(Devise).to receive(:direct_otp_length).and_return(nil)
      user = build(:user)
      user.send_new_otp

      expect(user.direct_otp.length).to eq 6
    end

    it 'is set to 6' do
      user = build(:user)
      user.send_new_otp

      expect(user.direct_otp.length).to eq 6
    end
  end

  describe '#decorate' do
    it 'returns a UserDecorator' do
      user = build(:user)

      expect(user.decorate).to be_a(UserDecorator)
    end
  end
end
