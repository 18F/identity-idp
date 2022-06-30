require 'rails_helper'
require 'saml_idp_constants'

RSpec.describe User do
  describe 'Associations' do
    it { is_expected.to have_many(:identities) }
    it { is_expected.to have_many(:agency_identities) }
    it { is_expected.to have_many(:profiles) }
    it { is_expected.to have_many(:events) }
    it { is_expected.to have_one(:account_reset_request) }
    it { is_expected.to have_many(:phone_configurations) }
    it { is_expected.to have_many(:webauthn_configurations) }
    it { is_expected.to have_one(:proofing_component) }
    it { is_expected.to have_many(:in_person_enrollments).dependent(:destroy) }
    it {
      is_expected.to have_one(:pending_in_person_enrollment).
      conditions(status: :pending).
      order(created_at: :desc).
      class_name('InPersonEnrollment').
      with_foreign_key(:user_id).
      inverse_of(:user).
      dependent(:destroy)
    }
  end

  it 'does not send an email when #create is called' do
    expect do
      User.create(email: 'nobody@nobody.com')
    end.to change(ActionMailer::Base.deliveries, :count).by(0)
  end

  describe 'password validations' do
    it 'allows long phrases that contain common words' do
      user = create(:user)
      user.password = 'a long password'

      expect(user).to be_valid
    end

    it 'allows unconfirmed visitors' do
      user = create(:user, :unconfirmed)
      user.password = 'a long password'

      expect(user).to be_valid
    end
  end

  describe 'uuid validations' do
    it 'uses a DB constraint to enforce presence' do
      user = create(:user)
      user.uuid = nil

      expect { user.save }.
        to raise_error(
          ActiveRecord::NotNullViolation,
          /null value in column "uuid".*violates not-null constraint/,
        )
    end

    it 'uses a DB index to enforce uniqueness' do
      user1 = create(:user)
      user1.save
      user2 = create(:user, email: "mkuniqu.#{user1.email}")
      user2.uuid = user1.uuid

      expect { user2.save }.
        to raise_error(
          ActiveRecord::StatementInvalid,
          /duplicate key value violates unique constraint/,
        )
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

      expect(MfaPolicy.new(user).two_factor_enabled?).to eq true
    end

    it 'is false when user does not have a phone' do
      user = create(:user)

      expect(MfaPolicy.new(user).two_factor_enabled?).to eq false
    end
  end

  context '#need_two_factor_authentication?' do
    let(:request) { ActionController::TestRequest.new }

    it 'is true when two_factor_enabled' do
      user = build_stubbed(:user)

      mock_mfa = MfaPolicy.new(user)
      allow(mock_mfa).to receive(:two_factor_enabled?).and_return true
      allow(MfaPolicy).to receive(:new).with(user).and_return mock_mfa

      expect(user.need_two_factor_authentication?(nil)).to be_truthy
    end

    it 'is false when not two_factor_enabled' do
      user = build_stubbed(:user)

      mock_mfa = MfaPolicy.new(user)
      allow(mock_mfa).to receive(:two_factor_enabled?).and_return false
      allow(MfaPolicy).to receive(:new).with(user).and_return(mock_mfa)

      expect(user.need_two_factor_authentication?(nil)).to be_falsey
    end
  end

  context 'when identities are present' do
    let(:user) { create(:user, :signed_up) }
    let(:active_identity) do
      ServiceProviderIdentity.create(service_provider: 'entity_id', session_uuid: SecureRandom.uuid)
    end
    let(:inactive_identity) do
      ServiceProviderIdentity.create(service_provider: 'entity_id2', session_uuid: nil)
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
      user.identities << ServiceProviderIdentity.create(
        service_provider: 'first',
        last_authenticated_at: Time.zone.now - 1.hour,
        session_uuid: SecureRandom.uuid,
      )
      user.identities << ServiceProviderIdentity.create(
        service_provider: 'last',
        last_authenticated_at: Time.zone.now,
        session_uuid: SecureRandom.uuid,
      )
    end

    describe '#last_identity' do
      it 'returns the most recently authenticated identity' do
        expect(user.last_identity.service_provider).to eq('last')
      end
    end
  end

  context 'when user has multiple profiles' do
    describe '#active_profile' do
      it 'returns the only active profile' do
        user = create(:user, :signed_up)
        profile1 = create(:profile, :active, :verified, user: user, pii: { first_name: 'Jane' })
        _profile2 = create(:profile, :verified, user: user, pii: { first_name: 'Susan' })

        expect(user.active_profile).to eq profile1
      end
    end
  end

  context 'when user has IPP enrollments' do
    let(:user) { create(:user, :signed_up) }

    let(:profile1) {
      create(:profile, :verification_cancelled, user: user, pii: { first_name: 'Jane' })
    }
    let(:profile2) {
      create(:profile, :verification_pending, user: user, pii: { first_name: 'Susan' })
    }

    let!(:enrollment1) { create(:in_person_enrollment, :failed, user: user, profile: profile1) }
    let!(:enrollment2) { create(:in_person_enrollment, :pending, user: user, profile: profile2) }

    describe '#in_person_enrollments' do
      it 'returns multiple IPP enrollments' do
        expect(user.in_person_enrollments).to eq [enrollment1, enrollment2]
      end

      it 'deletes everything and does not result in an error when'\
      ' the user is deleted before the profile' do
        enrollment_id1 = enrollment1.id
        enrollment_id2 = enrollment2.id
        profile_id1 = profile1.id
        profile_id2 = profile2.id
        user_id = user.id

        expect(User.find_by(id: user_id)).to eq user
        expect(Profile.find_by(id: profile_id1)).to eq profile1
        expect(Profile.find_by(id: profile_id2)).to eq profile2
        expect(InPersonEnrollment.find_by(id: enrollment_id1)).to eq enrollment1
        expect(InPersonEnrollment.find_by(id: enrollment_id2)).to eq enrollment2
        user.destroy
        expect(User.find_by(id: user_id)).to eq nil
        expect(Profile.find_by(id: profile_id1)).to eq nil
        expect(Profile.find_by(id: profile_id2)).to eq nil
        expect(InPersonEnrollment.find_by(id: enrollment_id1)).to eq nil
        expect(InPersonEnrollment.find_by(id: enrollment_id2)).to eq nil
        profile1.destroy # Profile is already deleted, but we shouldn't get an error here.
      end

      it 'deletes everything under the profile and does not result in an'\
      ' error when the profile is deleted before the user' do
        enrollment_id1 = enrollment1.id
        enrollment_id2 = enrollment2.id
        profile_id1 = profile1.id
        profile_id2 = profile2.id
        user_id = user.id

        expect(User.find_by(id: user_id)).to eq user
        expect(Profile.find_by(id: profile_id1)).to eq profile1
        expect(Profile.find_by(id: profile_id2)).to eq profile2
        expect(InPersonEnrollment.find_by(id: enrollment_id1)).to eq enrollment1
        expect(InPersonEnrollment.find_by(id: enrollment_id2)).to eq enrollment2
        profile1.destroy
        expect(User.find_by(id: user_id)).to eq user
        expect(Profile.find_by(id: profile_id1)).to eq nil
        expect(Profile.find_by(id: profile_id2)).to eq profile2
        expect(InPersonEnrollment.find_by(id: enrollment_id1)).to eq nil
        expect(InPersonEnrollment.find_by(id: enrollment_id2)).to eq enrollment2
        user.destroy # Should work even though first profile was deleted after user was loaded
      end
    end

    describe '#pending_in_person_enrollment' do
      it 'returns the pending IPP enrollment' do
        expect(user.pending_in_person_enrollment).to eq enrollment2
      end
    end
  end

  describe 'deleting identities' do
    it 'does not delete identities when the user is destroyed preventing uuid reuse' do
      user = create(:user, :signed_up)
      user.identities << ServiceProviderIdentity.create(
        service_provider: 'entity_id', session_uuid: SecureRandom.uuid,
      )
      user_id = user.id
      user.destroy!
      expect(ServiceProviderIdentity.where(user_id: user_id).length).to eq 1
    end
  end

  describe 'OTP length' do
    it 'uses TwoFactorAuthenticatable setting when set' do
      stub_const('TwoFactorAuthenticatable::DIRECT_OTP_LENGTH', 10)
      user = build(:user)
      user.create_direct_otp

      expect(user.direct_otp.length).to eq 10
    end

    it 'is set to 6' do
      user = build(:user)
      user.create_direct_otp

      expect(user.direct_otp.length).to eq 6
    end
  end

  describe '#decorate' do
    it 'returns a UserDecorator' do
      user = build(:user)

      expect(user.decorate).to be_a(UserDecorator)
    end
  end

  describe 'encrypted attributes' do
    context 'input is MixEd CaSe with whitespace' do
      it 'normalizes email' do
        user = create(:user, email: 'FoO@example.org    ')

        expect(user.email_addresses.first.email).to eq 'foo@example.org'
      end
    end

    it 'decrypts otp_secret_key' do
      user = create(:user, :with_authentication_app)
      AuthAppConfiguration.first.update!(otp_secret_key: 'abc123')

      expect(user.auth_app_configurations.first.otp_secret_key).to eq 'abc123'
    end
  end

  describe '.find_with_email' do
    it 'strips whitespace and downcases email before looking it up' do
      user = create(:user, email: 'test1@test.com')

      expect(User.find_with_email(' Test1@test.com ')).to eq user
    end

    it 'does not blow up with malformed input' do
      expect(User.find_with_email(foo: 'bar')).to eq(nil)
    end
  end

  describe '#authenticatable_salt' do
    it 'returns the password salt' do
      user = create(:user)
      salt = JSON.parse(user.encrypted_password_digest)['password_salt']

      expect(user.authenticatable_salt).to eq(salt)
    end
  end

  describe '#generate_totp_secret' do
    it 'generates a secret 32 characters long' do
      user = build(:user)
      secret = user.generate_totp_secret
      expect(secret.length).to eq 32
    end
  end

  describe '#accepted_rules_of_use_still_valid?' do
    let(:rules_of_use_horizon_years) { 6 }
    let(:rules_of_use_updated_at) { 1.day.ago }
    let(:accepted_terms_at) { nil }
    let(:user) { create(:user, :signed_up, accepted_terms_at: accepted_terms_at) }
    before do
      allow(IdentityConfig.store).to receive(:rules_of_use_horizon_years).
        and_return(rules_of_use_horizon_years)
      allow(IdentityConfig.store).to receive(:rules_of_use_updated_at).
        and_return(rules_of_use_updated_at)
    end

    context 'when a user has not accepted rules of use yet' do
      it 'should return a falsey value' do
        expect(user.accepted_rules_of_use_still_valid?).to be_falsey
      end
    end

    context 'with a user who is not up to date with rules of use' do
      let(:accepted_terms_at) { 3.days.ago }

      it 'should return a falsey value' do
        expect(user.accepted_rules_of_use_still_valid?).to be_falsey
      end
    end

    context 'with a user who is up to date with rules of use' do
      let(:accepted_terms_at) { 12.hours.ago }

      it 'should return a truthy value' do
        expect(user.accepted_rules_of_use_still_valid?).to be_truthy
      end
    end

    context 'with a user who accepted the rules of use more than 6 years ago' do
      let(:rules_of_use_horizon_years) { 6 }
      let(:rules_of_use_updated_at) { 7.years.ago }
      let(:accepted_terms_at) { 6.years.ago - 1.day }

      it 'should return a falsey value' do
        expect(user.accepted_rules_of_use_still_valid?).to be_falsey
      end
    end
  end

  context 'when a user has multiple phone_configurations' do
    before do
      @user = create(:user, email: 'test1@test.com')
      @phone_config1 = create(
        :phone_configuration, user: @user,
                              phone: '+1 111 111 1111',
                              created_at: Time.zone.now - 3.days,
                              made_default_at: nil
      )
      @phone_config2 = create(
        :phone_configuration, user: @user,
                              phone: '+1 222 222 2222',
                              created_at: Time.zone.now - 2.days,
                              made_default_at: nil
      )
      @phone_config3 = create(
        :phone_configuration, user: @user,
                              phone: '+1 333 333 3333',
                              created_at: Time.zone.now - 1.day,
                              made_default_at: nil
      )
    end

    describe '#default_phone_configuration' do
      it 'returns earliest created phone_configuration when no default set' do
        expect(@user.default_phone_configuration.phone).to eq('+1 111 111 1111')
      end

      it 'returns the latest default phone_configuration' do
        @phone_config3.update(made_default_at: Time.zone.now - 2.days)
        @phone_config2.update(made_default_at: Time.zone.now - 1.day)
        expect(@user.default_phone_configuration.phone).to eq('+1 222 222 2222')
      end
    end
  end

  describe '#pending_profile' do
    context 'when a profile with a verification_pending deactivation_reason exists' do
      it 'returns the most recent profile' do
        user = User.new
        _old_profile = create(
          :profile,
          :verification_pending,
          created_at: 1.day.ago,
          user: user,
        )
        new_profile = create(
          :profile,
          :verification_pending,
          user: user,
        )

        expect(user.pending_profile).to eq new_profile
      end
    end

    context 'when a verification_pending profile does not exist' do
      it 'returns nil' do
        user = User.new
        create(
          :profile,
          :password_reset,
          created_at: 1.day.ago,
          user: user,
        )
        create(
          :profile,
          deactivation_reason: :encryption_error,
          user: user,
        )

        expect(user.pending_profile).to be_nil
      end
    end
  end

  describe '#broken_personal_key?' do
    before do
      allow(IdentityConfig.store).to receive(:broken_personal_key_window_start).
        and_return(3.days.ago)
      allow(IdentityConfig.store).to receive(:broken_personal_key_window_finish).
        and_return(1.day.ago)
    end

    let(:user) { build(:user) }

    context 'for a user with no profile' do
      it { expect(user.broken_personal_key?).to eq(false) }
    end

    context 'for a user with a profile that is not verified' do
      before do
        create(:profile, user: user, activated_at: nil, verified_at: nil)
      end

      it { expect(user.broken_personal_key?).to eq(false) }
    end

    context 'for a user with a profile verified before the broken key window' do
      before do
        create(
          :profile,
          user: user,
          active: true,
          activated_at: 5.days.ago,
          verified_at: 5.days.ago,
        )
      end

      it { expect(user.broken_personal_key?).to eq(false) }
    end

    context 'for a user with a profile verified after the broken key window' do
      before do
        create(:profile, :active, :verified, user: user)
      end

      it { expect(user.broken_personal_key?).to eq(false) }
    end

    context 'for a user with a profile verified during the broken key window' do
      let(:personal_key_generated_at) { nil }
      let(:verified_at) { 2.days.ago }

      let(:user) do
        build(:user, encrypted_recovery_code_digest_generated_at: personal_key_generated_at)
      end

      before do
        create(
          :profile,
          user: user,
          active: true,
          activated_at: verified_at,
          verified_at: verified_at,
        )
      end

      context 'for a user missing the personal key verified timestamp (legacy data)' do
        let(:personal_key_generated_at) { nil }

        it { expect(user.broken_personal_key?).to eq(true) }
      end

      context 'for a personal key generated before the window ends' do
        let(:personal_key_generated_at) { 2.days.ago }

        it { expect(user.broken_personal_key?).to eq(true) }
      end

      context 'for a personal key generated after the window (fixed)' do
        let(:personal_key_generated_at) { Time.zone.now }

        it { expect(user.broken_personal_key?).to eq(false) }
      end
    end

    context 'for a user that has encrypted profile data that is suspiciously too short' do
      let(:user) { create(:user) }
      let(:personal_key) { RandomPhrase.new(num_words: 4).to_s }

      before do
        create(
          :profile,
          user: user,
          active: true,
          verified_at: Time.zone.now,
          encrypted_pii_recovery: Encryption::Encryptors::PiiEncryptor.new(personal_key).
            encrypt('null', user_uuid: user.uuid),
        )
      end

      it { expect(user.broken_personal_key?).to eq(true) }
    end
  end
end
