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

  describe '#fully_registered?' do
    let(:user) { create(:user) }
    subject(:fully_registered?) { user.fully_registered? }

    context 'with unconfirmed user' do
      let(:user) { create(:user, :unconfirmed) }

      it { expect(fully_registered?).to eq(false) }
    end

    context 'with confirmed user' do
      let(:user) { create(:user) }

      it { expect(fully_registered?).to eq(false) }
    end

    context 'with mfa-enabled user' do
      let(:user) { create(:user, :fully_registered) }

      it { expect(fully_registered?).to eq(true) }
    end
  end

  context 'when identities are present' do
    let(:user) { create(:user, :fully_registered) }
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
    let(:user) { create(:user, :fully_registered) }

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
        user = create(:user, :fully_registered)
        profile1 = create(:profile, :active, :verified, user: user, pii: { first_name: 'Jane' })
        _profile2 = create(:profile, :verified, user: user, pii: { first_name: 'Susan' })

        expect(user.active_profile).to eq profile1
      end
    end
  end

  context 'when user has IPP enrollments' do
    let(:user) { create(:user, :fully_registered) }

    let(:failed_enrollment_profile) do
      create(:profile, :verification_cancelled, user: user, pii: { first_name: 'Jane' })
    end
    let(:pending_enrollment_profile) do
      create(
        :profile,
        gpo_verification_pending_at: 1.day.ago,
        user: user,
        pii: { first_name: 'Susan' },
      )
    end

    let(:establishing_enrollment_profile) do
      create(
        :profile,
        gpo_verification_pending_at: 1.day.ago,
        user: user,
        pii: { first_name: 'Susan' },
      )
    end

    let!(:failed_enrollment) do
      create(:in_person_enrollment, :failed, user: user, profile: failed_enrollment_profile)
    end
    let!(:pending_enrollment) do
      create(:in_person_enrollment, :pending, user: user, profile: pending_enrollment_profile)
    end
    let!(:establishing_enrollment) do
      create(
        :in_person_enrollment,
        :establishing,
        user: user,
        profile: establishing_enrollment_profile,
      )
    end

    describe '#in_person_enrollments' do
      it 'returns multiple IPP enrollments' do
        expect(user.in_person_enrollments).to eq [
          failed_enrollment,
          pending_enrollment,
          establishing_enrollment,
        ]
      end

      it 'deletes everything and does not result in an error when'\
      ' the user is deleted before the profile' do
        failed_enrollment_id = failed_enrollment.id
        pending_enrollment_id = pending_enrollment.id
        establishing_enrollment_id = establishing_enrollment.id
        failed_enrollment_profile_id = failed_enrollment_profile.id
        pending_enrollment_profile_id = pending_enrollment_profile.id
        establishing_enrollment_profile_id = establishing_enrollment_profile.id
        user_id = user.id

        expect(User.find_by(id: user_id)).to eq user
        expect(Profile.find_by(id: failed_enrollment_profile_id)).to eq failed_enrollment_profile
        expect(Profile.find_by(id: pending_enrollment_profile_id)).to eq pending_enrollment_profile
        expect(Profile.find_by(id: establishing_enrollment_profile_id)).to eq(
          establishing_enrollment_profile,
        )
        expect(InPersonEnrollment.find_by(id: failed_enrollment_id)).to eq failed_enrollment
        expect(InPersonEnrollment.find_by(id: pending_enrollment_id)).to eq pending_enrollment
        expect(InPersonEnrollment.find_by(id: establishing_enrollment_id)).to eq(
          establishing_enrollment,
        )
        user.destroy
        expect(User.find_by(id: user_id)).to eq nil
        expect(Profile.find_by(id: failed_enrollment_profile_id)).to eq nil
        expect(Profile.find_by(id: pending_enrollment_profile_id)).to eq nil
        expect(Profile.find_by(id: establishing_enrollment_profile_id)).to eq nil
        expect(InPersonEnrollment.find_by(id: failed_enrollment_id)).to eq nil
        expect(InPersonEnrollment.find_by(id: pending_enrollment_id)).to eq nil
        expect(InPersonEnrollment.find_by(id: establishing_enrollment_id)).to eq nil
        failed_enrollment_profile.destroy # Profile is already deleted, but check for no errors
      end

      it 'deletes everything under the profile and does not result in an'\
      ' error when the profile is deleted before the user' do
        failed_enrollment_id = failed_enrollment.id
        pending_enrollment_id = pending_enrollment.id
        establishing_enrollment_id = establishing_enrollment.id
        failed_enrollment_profile_id = failed_enrollment_profile.id
        pending_enrollment_profile_id = pending_enrollment_profile.id
        establishing_enrollment_profile_id = establishing_enrollment_profile.id
        user_id = user.id

        expect(User.find_by(id: user_id)).to eq user
        expect(Profile.find_by(id: failed_enrollment_profile_id)).to eq failed_enrollment_profile
        expect(Profile.find_by(id: pending_enrollment_profile_id)).to eq pending_enrollment_profile
        expect(InPersonEnrollment.find_by(id: failed_enrollment_id)).to eq failed_enrollment
        expect(InPersonEnrollment.find_by(id: pending_enrollment_id)).to eq pending_enrollment
        expect(InPersonEnrollment.find_by(id: establishing_enrollment_id)).to eq(
          establishing_enrollment,
        )
        failed_enrollment_profile.destroy
        expect(User.find_by(id: user_id)).to eq user
        expect(Profile.find_by(id: failed_enrollment_profile_id)).to eq nil
        expect(Profile.find_by(id: pending_enrollment_profile_id)).to eq pending_enrollment_profile
        expect(Profile.find_by(id: establishing_enrollment_profile_id)).to eq(
          establishing_enrollment_profile,
        )
        expect(InPersonEnrollment.find_by(id: failed_enrollment_id)).to eq nil
        expect(InPersonEnrollment.find_by(id: pending_enrollment_id)).to eq pending_enrollment
        expect(InPersonEnrollment.find_by(id: establishing_enrollment_id)).to eq(
          establishing_enrollment,
        )
        user.destroy # Should work even though first profile was deleted after user was loaded
      end
    end

    describe '#pending_in_person_enrollment' do
      it 'returns the pending IPP enrollment' do
        expect(user.pending_in_person_enrollment).to eq pending_enrollment
      end
    end

    describe '#establishing_in_person_enrollment' do
      it 'returns the establishing IPP enrollment' do
        expect(user.establishing_in_person_enrollment).to eq establishing_enrollment
      end
    end

    describe '#has_in_person_enrollment?' do
      it 'returns the establishing IPP enrollment that has an address' do
        ProofingComponent.find_or_create_by(user: user).
          update!(document_check: Idp::Constants::Vendors::USPS)

        expect(user.has_in_person_enrollment?).to eq(true)
      end
    end

    # We don't know yet if #establishing_in_person_enrollment is, in fact, `establishing`
    # so we trust the pending profile in the meantime
    describe '#has_establishing_in_person_enrollment_safe?' do
      let(:new_user) { create(:user, :fully_registered) }
      let(:proofing_components) { nil }
      let(:new_pending_profile) do
        create(
          :profile,
          :verify_by_mail_pending,
          user: new_user,
          proofing_components: proofing_components,
        )
      end
      let!(:establishing_enrollment) do
        create(
          :in_person_enrollment,
          :establishing,
          profile: new_pending_profile,
          user: new_user,
        )
      end

      it 'returns the establishing IPP enrollment through the pending profile' do
        # trust pending_profile
        expect(new_user.has_establishing_in_person_enrollment_safe?).to eq(true)
      end
    end
  end

  describe 'deleting identities' do
    it 'does not delete identities when the user is destroyed preventing uuid reuse' do
      user = create(:user, :fully_registered)
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

  describe '#password=' do
    it 'digests and saves a single region and multi region password digests' do
      user = build(:user, password: nil)

      user.password = 'test password'

      expect(user.encrypted_password_digest).to_not be_blank
      expect(user.encrypted_password_digest).to_not match(/test password/)

      expect(user.encrypted_password_digest_multi_region).to_not be_blank
      expect(user.encrypted_password_digest_multi_region).to_not match(/test password/)

      expect(
        user.encrypted_password_digest,
      ).to_not eq(
        user.encrypted_password_digest_multi_region,
      )
    end
  end

  describe '#valid_password?' do
    it 'validates the password for a user with a multi-region digest' do
      user = build(:user, password: 'test password')

      expect(user.encrypted_password_digest_multi_region).to_not be_nil

      expect(user.valid_password?('test password')).to eq(true)
      expect(user.valid_password?('wrong password')).to eq(false)
    end

    it 'validates the password for a user with a only a single-region digest' do
      user = build(:user, password: 'test password')
      user.encrypted_password_digest_multi_region = nil

      expect(user.valid_password?('test password')).to eq(true)
      expect(user.valid_password?('wrong password')).to eq(false)
    end

    it 'validates the password for a user with a only a single-region UAK digest' do
      user = build(:user)
      user.encrypted_password_digest = Encryption::UakPasswordVerifier.digest('test password')
      user.encrypted_password_digest_multi_region = nil

      expect(user.valid_password?('test password')).to eq(true)
      expect(user.valid_password?('wrong password')).to eq(false)
    end
  end

  describe '#personal_key=' do
    it 'digests and saves a single region and multi region personal key digests' do
      user = build(:user, personal_key: nil)

      user.personal_key = 'test personal key'

      expect(user.encrypted_recovery_code_digest).to_not be_blank
      expect(user.encrypted_recovery_code_digest).to_not match(/test personal key/)

      expect(user.encrypted_recovery_code_digest_multi_region).to_not be_blank
      expect(user.encrypted_recovery_code_digest_multi_region).to_not match(/test personal key/)

      expect(
        user.encrypted_recovery_code_digest,
      ).to_not eq(
        user.encrypted_recovery_code_digest_multi_region,
      )
    end
  end

  describe '#valid_personal_key?' do
    it 'validates the personal key for a user with a multi-region digest' do
      user = build(:user, personal_key: 'test personal key')

      expect(user.encrypted_recovery_code_digest_multi_region).to_not be_nil

      expect(user.valid_personal_key?('test personal key')).to eq(true)
      expect(user.valid_personal_key?('wrong personal key')).to eq(false)
    end

    it 'validates the personal key for a user with a only a single-region digest' do
      user = build(:user, personal_key: 'test personal key')
      user.encrypted_recovery_code_digest_multi_region = nil

      expect(user.valid_personal_key?('test personal key')).to eq(true)
      expect(user.valid_personal_key?('wrong personal key')).to eq(false)
    end

    it 'validates the personal key for a user with a only a single-region UAK digest' do
      user = build(:user)
      user.encrypted_recovery_code_digest =
        Encryption::UakPasswordVerifier.digest('test personal key')
      user.encrypted_recovery_code_digest_multi_region = nil

      expect(user.valid_personal_key?('test personal key')).to eq(true)
      expect(user.valid_personal_key?('wrong personal key')).to eq(false)
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
    let(:user) { create(:user, :fully_registered, accepted_terms_at: accepted_terms_at) }
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
    context 'when a pending profile exists' do
      let(:user) { User.new }
      let!(:pending) do
        create(
          :profile,
          gpo_verification_pending_at: 2.days.ago,
          created_at: 2.days.ago,
          user: user,
        )
      end

      it 'returns nil if the active profile is newer than the pending profile' do
        allow(user).to receive(:active_profile).and_return(Profile.new(activated_at: Time.zone.now))

        expect(user.pending_profile).to be_nil
      end

      it 'returns the profile if the active profile is older than the pending profile' do
        allow(user).to receive(:active_profile).and_return(Profile.new(activated_at: 3.days.ago))

        expect(user.pending_profile).to eq pending
      end
    end

    context 'when pending profile does not exist' do
      it 'returns nil' do
        user = User.new
        create(
          :profile,
          deactivation_reason: :encryption_error,
          user: user,
        )

        expect(user.pending_profile).to be_nil
      end
    end

    context 'verification was cancelled for a pending profile' do
      it 'return nil' do
        user = User.new
        create(
          :profile,
          gpo_verification_pending_at: Time.zone.now,
          deactivation_reason: :verification_cancelled,
          user: user,
        )

        expect(user.pending_profile).to be_nil
      end
    end

    context 'the pending profile is stuck because of a password reset' do
      it 'return nil' do
        user = User.new
        create(
          :profile,
          gpo_verification_pending_at: Time.zone.now,
          deactivation_reason: :password_reset,
          user: user,
        )

        expect(user.pending_profile).to be_nil
      end
    end
  end

  describe '#gpo_verification_pending_profile' do
    context 'when a profile with a gpo_verification_pending_at timestamp exists' do
      it 'returns the profile' do
        user = User.new
        profile = create(
          :profile,
          gpo_verification_pending_at: Time.zone.now,
          user: user,
        )

        expect(user.gpo_verification_pending_profile).to eq profile
      end
    end

    context 'when a gpo_verification_pending profile does not exist' do
      it 'returns nil' do
        user = User.new
        create(
          :profile,
          :verified,
          :password_reset,
          created_at: 1.day.ago,
          user: user,
        )
        create(
          :profile,
          deactivation_reason: :encryption_error,
          user: user,
        )

        expect(user.gpo_verification_pending_profile).to be_nil
      end
    end
  end

  describe '#fraud_review_pending?' do
    it 'returns true if fraud review is pending' do
      user = create(:user)
      create(:profile, :fraud_review_pending, user: user)

      expect(user.fraud_review_pending?).to eq true
    end
  end

  describe '#fraud_rejection?' do
    it 'returns true if fraud rejection' do
      user = create(:user)
      create(:profile, :fraud_rejection, user: user)

      expect(user.fraud_rejection?).to eq true
    end
  end

  describe '#fraud_review_pending_profile' do
    context 'with a fraud review pending profile' do
      it 'returns the profile pending review' do
        user = create(:user)
        profile = create(:profile, :fraud_review_pending, user: user)

        expect(user.fraud_review_pending_profile).to eq(profile)
      end
    end

    context 'without a fraud review pending profile' do
      user = User.new
      it { expect(user.fraud_review_pending_profile).to eq(nil) }
    end
  end

  describe '#fraud_rejection_profile' do
    context 'with a fraud rejection profile' do
      it 'returns the profile with rejection' do
        user = create(:user)
        profile = create(:profile, :fraud_rejection, user: user)

        expect(user.fraud_rejection_profile).to eq(profile)
      end
    end

    context 'without a fraud rejection profile' do
      user = User.new
      it { expect(user.fraud_rejection_profile).to eq(nil) }
    end
  end

  describe '#personal_key_generated_at' do
    let(:user) do
      build(:user, encrypted_recovery_code_digest_generated_at: digest_generated_at)
    end
    let(:digest_generated_at) { nil }

    context 'the user has a encrypted_recovery_code_digest_generated_at date' do
      let(:digest_generated_at) { 1.day.ago }

      it 'returns the date in the digest' do
        expect(
          user.personal_key_generated_at,
        ).to be_within(1.second).of(digest_generated_at)
      end
    end

    context 'the user does not have a encrypted_recovery_code_digest_generated_at but is proofed' do
      let!(:profile) do
        create(
          :profile,
          :active,
          :verified,
          user: user,
        )
      end

      it 'returns the date the user was proofed' do
        expect(
          user.personal_key_generated_at,
        ).to be_within(1.second).of(profile.verified_at)
      end
    end

    context 'the user has no encrypted_recovery_code_digest_generated_at and is not proofed' do
      it 'returns nil' do
        expect(user.personal_key_generated_at).to be_nil
      end
    end

    context 'the user has no active profile but has a previously verified profile' do
      let!(:verified_profile) do
        create(
          :profile,
          :verified,
          user: user,
        )
      end

      let!(:verification_cancelled_profile) do
        create(
          :profile,
          :verification_cancelled,
          user: user,
        )
      end

      it 'returns the date of the previously verified profile' do
        expect(
          user.personal_key_generated_at,
        ).to be_within(1.second).of(verified_profile.verified_at)
      end
    end
  end

  describe 'user suspension' do
    let(:user) { create(:user) }
    let(:cannot_reinstate_message) { :user_is_not_suspended }
    let(:cannot_suspend_message) { :user_already_suspended }

    describe '#suspended?' do
      context 'when suspended_at is after reinstated_at' do
        before do
          user.suspended_at = Time.zone.now
          user.reinstated_at = Time.zone.now - 1.day
        end
        it 'returns true' do
          expect(user.suspended?).to be true
        end
      end

      context 'when suspended_at is before reinstated_at' do
        before do
          user.suspended_at = Time.zone.now - 1.day
          user.reinstated_at = Time.zone.now
        end

        it 'returns false' do
          expect(user.suspended?).to be false
        end
      end

      context 'when suspended_at is nil' do
        before do
          user.suspended_at = nil
          user.reinstated_at = nil
        end

        it 'returns false' do
          expect(user.suspended?).to be false
        end
      end
    end

    describe '#reinstated?' do
      context 'when reinstated_at is after suspended_at' do
        before do
          user.suspended_at = Time.zone.now - 1.day
          user.reinstated_at = Time.zone.now
        end

        it 'returns true' do
          expect(user.reinstated?).to be true
        end
      end

      context 'when reinstated_at is before suspended_at' do
        before do
          user.suspended_at = Time.zone.now
          user.reinstated_at = Time.zone.now - 1.day
        end

        it 'returns false' do
          expect(user.reinstated?).to be false
        end
      end

      context 'when reinstated_at is nil' do
        before do
          user.suspended_at = nil
          user.reinstated_at = nil
        end
        it 'returns false' do
          expect(user.reinstated?).to be false
        end
      end
    end

    describe '#suspend!' do
      context 'user is not already suspended' do
        let(:mock_session_id) { SecureRandom.uuid }
        before do
          UpdateUser.new(user: user, attributes: { unique_session_id: mock_session_id }).call
        end

        it 'creates SuspendedEmail records for each email address' do
          expect { user.suspend! }.to(change { SuspendedEmail.count }.by(1))
        end

        it 'updates the suspended_at attribute with the current time' do
          expect do
            user.suspend!
          end.to change(user, :suspended_at).from(nil).to(be_within(1.second).of(Time.zone.now))
        end

        it 'updates the unique_session_id attribute to be nil' do
          expect do
            user.suspend!
          end.to change(user, :unique_session_id).from(mock_session_id).to(nil)
        end

        it 'tracks the user suspension' do
          expect(user.analytics).to receive(:user_suspended).with(success: true)
          user.suspend!
        end

        it 'logs out the suspended user from the active session' do
          # Add information to session store to allow `exists?` check to work as desired
          OutOfBandSessionAccessor.new(mock_session_id).put_pii(
            { first_name: 'Mario' },
            5.minutes.to_i,
          )

          expect(OutOfBandSessionAccessor.new(mock_session_id).exists?).to eq true

          user.suspend!

          expect(OutOfBandSessionAccessor.new(mock_session_id).exists?).to eq false
        end

        context 'user has a nil current session id' do
          let(:mock_session_id) { nil }

          it 'does not error' do
            expect { user.suspend! }.to_not raise_error
          end
        end
      end

      it 'raises an error if the user is already suspended' do
        user.suspended_at = Time.zone.now
        expect(user.analytics).to receive(:user_suspended).with(
          success: false,
          error_message: cannot_suspend_message,
        )
        expect do
          user.suspend!
        end.to raise_error(cannot_suspend_message.to_s)
      end
    end

    describe '#reinstate!' do
      before do
        user.suspend!
        user.reinstated_at = nil
      end

      it 'destroys SuspendedEmail records for each email address' do
        email_addresses = user.email_addresses
        email_address = email_addresses.last
        expect(email_addresses.count).to eq 1
        expect { user.reinstate! }.
          to(change { SuspendedEmail.find_with_email(email_address.email) }.to(nil))
        expect(user.email_addresses.reload.last).to be_present
      end

      it 'updates the reinstated_at attribute with the current time' do
        expect do
          user.reinstate!
        end.to change(user, :reinstated_at).from(nil).to(be_within(1.second).of(Time.zone.now))
      end

      it 'tracks the user reinstatement' do
        expect(user.analytics).to receive(:user_reinstated).with(success: true)
        user.reinstate!
      end

      it 'raises an error if the user is not currently suspended' do
        user.suspended_at = nil
        expect(user.analytics).to receive(:user_reinstated).with(
          success: false,
          error_message: cannot_reinstate_message,
        )
        expect do
          user.reinstate!
        end.to raise_error(cannot_reinstate_message.to_s)
      end
    end
  end

  describe '#should_receive_in_person_completion_survey?' do
    let!(:user) { create(:user) }
    let(:service_provider) { create(:service_provider) }
    let(:issuer) { service_provider.issuer }

    before do
      allow(Idv::InPersonConfig).to receive(:enabled_for_issuer?).
        and_return(true)
    end

    def test_send_survey(should_send)
      expect(user.should_receive_in_person_completion_survey?(issuer)).to be(should_send)
      user.mark_in_person_completion_survey_sent(issuer)
      expect(user.should_receive_in_person_completion_survey?(issuer)).to be(false)
    end

    def it_should_send_survey
      test_send_survey(true)
    end

    def it_should_not_send_survey
      test_send_survey(false)
    end

    context 'user has no enrollments' do
      it 'should not send survey' do
        it_should_not_send_survey
      end
    end
    context 'user has completed enrollment for different issuer but no survey' do
      let(:other_service_provider) { create(:service_provider, issuer: 'otherissuer') }
      let!(:enrollment) do
        create(
          :in_person_enrollment, user: user, issuer: other_service_provider.issuer,
                                 status: :passed
        )
      end
      it 'should not send survey' do
        it_should_not_send_survey
      end
    end
    context 'user has completed survey for other issuer and enrollments for both issuers' do
      let(:other_service_provider) { create(:service_provider, issuer: 'otherissuer') }
      let!(:enrollment) do
        create(:in_person_enrollment, user: user, issuer: issuer, status: :passed)
      end
      let!(:enrollment2) do
        create(
          :in_person_enrollment, user: user, issuer: other_service_provider.issuer,
                                 status: :passed, follow_up_survey_sent: true
        )
      end
      it 'should send survey' do
        it_should_send_survey
      end
    end
    context 'user has incomplete enrollment but no survey' do
      let!(:user) { create(:user, :with_pending_in_person_enrollment) }
      it 'should not send survey' do
        it_should_not_send_survey
      end
    end
    context 'user has completed enrollment but no survey' do
      let!(:enrollment) do
        create(:in_person_enrollment, user: user, issuer: issuer, status: :passed)
      end
      it 'should send survey' do
        it_should_send_survey
      end
    end
    context 'user has multiple enrollments but only completed a survey for the last one' do
      let!(:enrollment) do
        create(:in_person_enrollment, user: user, issuer: issuer, status: :passed)
      end
      let!(:enrollment2) do
        create(
          :in_person_enrollment, user: user, issuer: issuer, status: :passed,
                                 follow_up_survey_sent: true
        )
      end
      it 'should not send survey' do
        it_should_not_send_survey
      end
    end
    context 'user has completed enrollment but no survey and feature is disabled' do
      let!(:enrollment) do
        create(:in_person_enrollment, user: user, issuer: issuer, status: :passed)
      end

      before do
        allow(Idv::InPersonConfig).to receive(:enabled_for_issuer?).
          and_return(false)
      end

      it 'should not send survey' do
        it_should_not_send_survey
      end
    end
    context 'user has completed enrollment and survey' do
      let!(:enrollment) do
        create(
          :in_person_enrollment, user: user, issuer: issuer, status: :passed,
                                 follow_up_survey_sent: true
        )
      end

      it 'should not send survey' do
        it_should_not_send_survey
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
        encrypted_pii_recovery, encrypted_pii_recovery_multi_region =
          Encryption::Encryptors::PiiEncryptor.new(
            personal_key,
          ).encrypt('null', user_uuid: user.uuid).single_region_ciphertext

        create(
          :profile,
          user: user,
          active: true,
          verified_at: Time.zone.now,
          encrypted_pii_recovery: encrypted_pii_recovery,
          encrypted_pii_recovery_multi_region: encrypted_pii_recovery_multi_region,
        )
      end

      it { expect(user.broken_personal_key?).to eq(true) }
    end
  end

  describe '#visible_email_addresses' do
    let(:user) { create(:user) }
    let(:confirmed_email_address) { user.email_addresses.detect(&:confirmed?) }
    let!(:unconfirmed_expired_email_address) do
      create(
        :email_address,
        user: user,
        confirmed_at: nil,
        confirmation_sent_at: 36.hours.ago,
      )
    end
    let!(:unconfirmed_unexpired_email_address) do
      create(
        :email_address,
        user: user,
        confirmed_at: nil,
        confirmation_sent_at: 5.minutes.ago,
      )
    end

    it 'shows email addresses that have been confirmed' do
      expect(user.visible_email_addresses).to include(confirmed_email_address)
    end

    it 'hides emails address that are unconfirmed and expired' do
      expect(user.visible_email_addresses).to_not include(unconfirmed_expired_email_address)
    end

    it 'shows emails that are not confirmed and not expired' do
      expect(user.visible_email_addresses).to include(unconfirmed_unexpired_email_address)
    end
  end

  describe '#email_language_preference_description' do
    let(:user) { build_stubbed(:user, email_language: email_language) }

    subject(:description) { user.email_language_preference_description }

    context 'when the user has a supported email_language' do
      let(:email_language) { 'es' }

      it 'is the that language' do
        expect(description).to eq(I18n.t('account.email_language.name.es'))
      end
    end

    context 'when the user has a nil email_language' do
      let(:email_language) { nil }

      it 'is the default language' do
        expect(description).to eq(I18n.t('account.email_language.name.en'))
      end
    end

    context 'when the user has an unsupported email_language' do
      let(:email_language) { 'zz' }

      it 'is the default language' do
        expect(description).to eq(I18n.t('account.email_language.name.en'))
      end
    end
  end

  describe '#lockout_time_expiration' do
    it 'returns the time at which lockout will expire' do
      freeze_time do
        user = build_stubbed(:user, second_factor_locked_at: Time.zone.now - 180)
        allow(IdentityConfig.store).to receive(:lockout_period_in_minutes).and_return(8)

        expect(user.lockout_time_expiration).to eq Time.zone.now + 300
      end
    end
  end

  describe '#active_identity_for' do
    it 'returns Identity matching ServiceProvider' do
      sp = create(:service_provider, issuer: 'http://sp.example.com')
      user = create(:user)
      user.identities << create(
        :service_provider_identity,
        service_provider: sp.issuer,
        session_uuid: SecureRandom.uuid,
      )

      expect(user.active_identity_for(sp)).to eq user.last_identity
    end
  end

  describe '#identity_not_verified?' do
    it 'returns true if identity_verified returns false' do
      user = User.new
      allow(user).to receive(:identity_verified?).and_return(false)

      expect(user.identity_not_verified?).to eq true
    end

    it 'returns false if identity_verified returns true' do
      user = User.new
      allow(user).to receive(:identity_verified?).and_return(true)

      expect(user.identity_not_verified?).to eq false
    end
  end

  describe '#identity_verified?' do
    it 'returns true if user has an active profile' do
      user = User.new
      allow(user).to receive(:active_profile).and_return(Profile.new)

      expect(user.identity_verified?).to eq true
    end

    it 'returns false if user does not have an active profile' do
      user = User.new
      allow(user).to receive(:active_profile).and_return(nil)

      expect(user.identity_verified?).to eq false
    end
  end

  describe '#locked_out?' do
    let(:locked_at) { nil }
    let(:user) { User.new }

    before { allow(user).to receive(:second_factor_locked_at).and_return(locked_at) }

    around do |ex|
      freeze_time { ex.run }
    end

    it { expect(user.locked_out?).to eq(false) }

    context 'second factor locked out recently' do
      let(:locked_at) { Time.zone.now }

      it { expect(user.locked_out?).to eq(true) }
    end

    context 'second factor locked out a while ago' do
      let(:locked_at) { IdentityConfig.store.lockout_period_in_minutes.minutes.ago - 1.second }

      it { expect(user.locked_out?).to eq(false) }
    end
  end

  describe '#no_longer_locked_out?' do
    let(:locked_at) { nil }
    let(:user) { User.new }

    before { allow(user).to receive(:second_factor_locked_at).and_return(locked_at) }

    around do |ex|
      freeze_time { ex.run }
    end

    subject(:no_longer_locked_out?) { user.no_longer_locked_out? }

    it { expect(no_longer_locked_out?).to eq(false) }

    context 'second factor locked out recently' do
      let(:locked_at) { Time.zone.now }

      it { expect(no_longer_locked_out?).to eq(false) }
    end

    context 'second factor locked out a while ago' do
      let(:locked_at) { IdentityConfig.store.lockout_period_in_minutes.minutes.ago - 1.second }

      it { expect(no_longer_locked_out?).to eq(true) }
    end
  end

  describe '#recent_events' do
    let!(:user) { create(:user, :fully_registered, created_at: Time.zone.now - 100.days) }

    let!(:event) { create(:event, user: user, created_at: Time.zone.now - 98.days) }
    let!(:identity) do
      create(
        :service_provider_identity,
        :active,
        user: user,
        last_authenticated_at: Time.zone.now - 60.days,
      )
    end
    let!(:another_event) do
      create(:event, user: user, event_type: :email_changed, created_at: Time.zone.now - 30.days)
    end

    it 'interleaves identities and events, decorates events, and sorts them in descending order' do
      expect(user.recent_events).
        to eq [another_event.decorate, identity, event.decorate]
    end
  end

  describe '#has_devices?' do
    let(:user) { create(:user) }
    subject(:has_devices?) { user.has_devices? }

    context 'with no devices' do
      it { expect(has_devices?).to eq(false) }
    end

    context 'with a device' do
      before do
        create(:device, user:)
      end

      it { expect(has_devices?).to eq(true) }
    end
  end

  describe '#password_reset_profile' do
    let(:user) { create(:user) }

    context 'with no profiles' do
      it { expect(user.password_reset_profile).to be_nil }
    end

    context 'with an active profile' do
      let(:active_profile) do
        build(:profile, :active, :verified, activated_at: 1.day.ago, pii: { first_name: 'Jane' })
      end

      before do
        user.profiles << [
          active_profile,
          build(:profile, :verified, activated_at: 5.days.ago, pii: { first_name: 'Susan' }),
        ]
      end

      it { expect(user.password_reset_profile).to be_nil }

      context 'when the active profile is deactivated due to password reset' do
        before { active_profile.deactivate(:password_reset) }

        it { expect(user.password_reset_profile).to eq(active_profile) }

        context 'with a previously-cancelled pending profile' do
          before do
            user.profiles << build(:profile, :verification_cancelled)
          end

          it { expect(user.password_reset_profile).to eq(active_profile) }
        end
      end
    end
  end

  describe '#delete_account_bullet_key' do
    let(:user) { build_stubbed(:user) }

    it 'returns ial1 if identity is not verified' do
      allow(user).to receive(:identity_verified?).and_return(false)
      expect(user.delete_account_bullet_key).
        to eq t('users.delete.bullet_2_basic', app_name: APP_NAME)
    end

    it 'returns ial2 if identity is verified' do
      allow(user).to receive(:identity_verified?).and_return(true)
      expect(user.delete_account_bullet_key).
        to eq t('users.delete.bullet_2_verified', app_name: APP_NAME)
    end
  end

  describe '#connected_apps' do
    let(:user) { create(:user) }
    let(:app) { create(:service_provider_identity, service_provider: 'aaa') }
    let(:deleted_app) do
      create(:service_provider_identity, service_provider: 'bbb', deleted_at: 5.days.ago)
    end

    before { user.identities << app << deleted_app }

    it 'omits deleted apps' do
      expect(user.connected_apps).to eq([app])
    end
  end

  describe '#sign_in_count' do
    it 'returns sign-in event count since the given time' do
      freeze_time do
        user = create(:user)
        user.events.create(event_type: :sign_in_before_2fa, created_at: 1.day.ago)
        user.events.create(event_type: :email_changed, created_at: 1.day.ago)
        user.events.create(event_type: :sign_in_before_2fa, created_at: 2.days.ago)
        user.events.create(event_type: :sign_in_before_2fa, created_at: 3.days.ago)

        expect(user.sign_in_count(since: 2.days.ago)).to eq(2)
      end
    end
  end

  describe '#second_last_signed_in_at' do
    it 'returns second most recent full authentication event' do
      user = create(:user)
      _event1 = create(:event, user: user, event_type: 'sign_in_after_2fa')
      event2 = create(:event, user: user, event_type: 'sign_in_after_2fa')
      _event3 = create(:event, user: user, event_type: 'sign_in_after_2fa')

      expect(user.second_last_signed_in_at).to eq(event2.reload.created_at)
    end
  end

  describe '#reproof_for_irs?' do
    let(:service_provider) { create(:service_provider) }

    it 'returns false if the service provider is not an attempts API service provider' do
      user = create(:user, :proofed)

      expect(user.reproof_for_irs?(service_provider: service_provider)).to be_falsy
    end

    context 'an attempts API service provider' do
      let(:service_provider) { create(:service_provider, :irs) }

      it 'returns false if the user has not proofed before' do
        user = create(:user)

        expect(user.reproof_for_irs?(service_provider: service_provider)).to be_falsy
      end

      it 'returns false if the active profile initiating SP was an attempts API SP' do
        user = create(:user, :proofed)

        user.active_profile.update!(initiating_service_provider: service_provider)

        expect(user.reproof_for_irs?(service_provider: service_provider)).to be_falsy
      end

      it 'returns true if the active profile initiating SP was not an attempts API SP' do
        user = create(:user, :proofed)

        expect(user.reproof_for_irs?(service_provider: service_provider)).to be_truthy
      end
    end
  end
end
