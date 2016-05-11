require 'saml_idp_constants'

MAX_GOOD_PASSWORD = '!1aZ' * 32

describe User do
  it 'should only send one email during creation' do
    expect do
      User.create(email: 'nobody@nobody.com')
    end.to change(ActionMailer::Base.deliveries, :count).by(1)
  end

  context '.create' do
    it 'accepts a valid email' do
      user = create(:user)
      expect(user.errors.any?).to be_falsey
    end

    it 'raises an error with an invalid email' do
      expect { create(:user, email: 'invalid@email') }.to raise_error(
        ActiveRecord::RecordInvalid)
    end
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

  context '.password_strength' do
    it 'requires a digit' do
      NO_NUM_PASSWORD = 'abcdABCD!@#$'.freeze

      # Verify failure on create.
      # TODO: JJG restore check for error message
      expect do
        create(:user,
               password: NO_NUM_PASSWORD,
               password_confirmation: NO_NUM_PASSWORD)
      end.
        to raise_error(ActiveRecord::RecordInvalid)

      prototype_user = create(:user)

      # Verify success.
      (0..9).each do |digit|
        password = "#{NO_NUM_PASSWORD}#{digit}"
        user = create(:user,
                      email: "#{digit}.#{prototype_user.email}",
                      password: password,
                      password_confirmation: password)
        expect(user.errors.any?).to be_falsey
      end

      # Verifying password updating enforces complexity requirements.
      (0..9).each do |digit|
        prototype_user.password = NO_NUM_PASSWORD
        prototype_user.password_confirmation = NO_NUM_PASSWORD
        expect(prototype_user.valid?).to be_falsey
        prototype_user.password = "#{NO_NUM_PASSWORD}#{digit}"
        prototype_user.password_confirmation = "#{NO_NUM_PASSWORD}#{digit}"
        expect(prototype_user.valid?).to be_truthy
      end
    end

    it 'requires a capital letter' do
      NO_CAP_PASSWORD = 'abcd1234!@#$'.freeze

      # Verify failure on create.
      # TODO: JJG restore check for error message
      expect do
        create(:user,
               password: NO_CAP_PASSWORD,
               password_confirmation: NO_CAP_PASSWORD)
      end.
        to raise_error(ActiveRecord::RecordInvalid)

      prototype_user = create(:user)

      # Verify success.
      ('A'..'Z').each do |capital|
        password = "#{NO_CAP_PASSWORD}#{capital}"
        user = create(:user,
                      email: "#{capital}.#{prototype_user.email}",
                      password: password,
                      password_confirmation: password)
        expect(user.errors.any?).to be_falsey
      end

      # Verifying password updating enforces complexity requirements.
      ('A'..'Z').each do |capital|
        prototype_user.password = NO_CAP_PASSWORD
        prototype_user.password_confirmation = NO_CAP_PASSWORD
        expect(prototype_user.valid?).to be_falsey
        prototype_user.password = "#{NO_CAP_PASSWORD}#{capital}"
        prototype_user.password_confirmation = "#{NO_CAP_PASSWORD}#{capital}"
        expect(prototype_user.valid?).to be_truthy
      end
    end

    it 'requires a lowercase letter' do
      NO_LOWER_PASSWORD = 'ABCD1234!@#$'.freeze

      # Verify failure on create.
      # TODO: JJG restore check for error message
      expect do
        create(:user,
               password: NO_LOWER_PASSWORD,
               password_confirmation: NO_LOWER_PASSWORD)
      end.to raise_error(ActiveRecord::RecordInvalid)

      prototype_user = create(:user)

      # Verify success.
      ('a'..'z').each do |lower|
        password = "#{NO_LOWER_PASSWORD}#{lower}"
        user = create(:user,
                      email: "#{lower}.#{prototype_user.email}",
                      password: password,
                      password_confirmation: password)
        expect(user.errors.any?).to be_falsey
      end

      # Verifying password updating enforces complexity requirements.
      ('a'..'z').each do |lower|
        prototype_user.password = NO_LOWER_PASSWORD
        prototype_user.password_confirmation = NO_LOWER_PASSWORD
        expect(prototype_user.valid?).to be_falsey
        prototype_user.password = "#{NO_LOWER_PASSWORD}#{lower}"
        prototype_user.password_confirmation = "#{NO_LOWER_PASSWORD}#{lower}"
        expect(prototype_user.valid?).to be_truthy
      end
    end

    it 'requires a special character' do
      # Verify failure.
      NO_SPECIAL_PASSWORD = 'ABCD1234abcd'.freeze

      # Verify failure on create.
      expect do
        create(:user,
               password: NO_SPECIAL_PASSWORD,
               password_confirmation: NO_SPECIAL_PASSWORD)
      end.
        to raise_error(ActiveRecord::RecordInvalid
                      )

      prototype_user = create(:user)

      # Verify success.
      i = 1
      Saml::Idp::Constants::PASSWORD_SPECIAL_CHARS.each_char do |special|
        password = "#{NO_SPECIAL_PASSWORD}#{special}"
        user = create(:user,
                      email: "#{i}.#{prototype_user.email}",
                      password: password,
                      password_confirmation: password)
        expect(user.errors.any?).to be_falsey
        i += 1
      end

      # Verifying password updating enforces complexity requirements.
      Saml::Idp::Constants::PASSWORD_SPECIAL_CHARS.each_char do |special|
        prototype_user.password = NO_SPECIAL_PASSWORD
        prototype_user.password_confirmation = NO_SPECIAL_PASSWORD
        expect(prototype_user.valid?).to be_falsey
        prototype_user.password = "#{NO_SPECIAL_PASSWORD}#{special}"
        prototype_user.password_confirmation = "#{NO_SPECIAL_PASSWORD}#{special}"
        expect(prototype_user.valid?).to be_truthy
        i += 1
      end
    end

    it 'must be more than 8 characters' do
      prototype_user = create(:user)
      expect do
        create(:user,
               email: "mkuniq.#{prototype_user.email}",
               password: prototype_user.password.slice(0..6),
               password_confirmation: prototype_user.password.slice(0..6))
      end.
        to raise_error(ActiveRecord::RecordInvalid,
                       /Validation failed: Password is too short \(minimum is 8 characters\)/)
    end

    it 'cannot exceed 128 characters' do
      prototype_user = create(:user)
      expect do
        create(:user,
               email: "mkuniq.#{prototype_user.email}",
               password: prototype_user.password + '1',
               password_confirmation: prototype_user.password + '1')
      end.
        to raise_error(ActiveRecord::RecordInvalid,
                       /Validation failed: Password is too long \(maximum is 128 characters\)/)
    end
  end

  context '#two_factor_enabled?' do
    it 'is true when user has a confirmed mobile' do
      user = create(:user, :with_mobile)

      expect(user.two_factor_enabled?).to eq true
    end

    it 'is false when user has an unconfirmed mobile' do
      user = create(:user, unconfirmed_mobile: '123456789')

      expect(user.two_factor_enabled?).to eq false
    end

    it 'is false when user does not have a mobile' do
      user = create(:user)

      expect(user.two_factor_enabled?).to eq false
    end
  end

  context '#need_two_factor_authentication?' do
    let(:request) { ActionController::TestRequest.new }

    it 'is true when two_factor_enabled' do
      user = build_stubbed(:user)

      allow(user).to receive(:third_party_authenticated?).and_return(false)
      allow(user).to receive(:two_factor_enabled?).and_return true

      expect(user.need_two_factor_authentication?(nil)).to be_truthy
    end

    it 'is false when not two_factor_enabled' do
      user = build_stubbed(:user)

      allow(user).to receive(:third_party_authenticated?).and_return(false)
      allow(user).to receive(:two_factor_enabled?).and_return false

      expect(user.need_two_factor_authentication?(nil)).to be_falsey
    end

    it 'is false when signed up and authenticating with third party' do
      user = create(:user, :signed_up)
      allow(user).to receive(:third_party_authenticated?).with(request).and_return(true)
      expect(user.need_two_factor_authentication?(request)).to be_falsey
    end

    it 'is false when 2fa is enabled and authenticating with third party' do
      user = create(:user, :signed_up)
      allow(user).to receive(:third_party_authenticated?).with(request).and_return(true)
      expect(user.need_two_factor_authentication?(request)).to be_falsey
    end

    it 'is true when 2fa is enabled and not authenticating with third party' do
      user = create(:user, :signed_up)
      allow(user).to receive(:third_party_authenticated?).with(request).and_return(false)
      expect(user.need_two_factor_authentication?(request)).to be_truthy
    end

    it 'is false when 2fa is not enabled and authenticating with third party' do
      user = create(:user)
      allow(user).to receive(:third_party_authenticated?).with(request).and_return(true)
      expect(user.need_two_factor_authentication?(request)).to be_falsey
    end

    it 'is false when 2fa is not enabled and not authenticating with third party' do
      user = create(:user)
      allow(user).to receive(:third_party_authenticated?).with(request).and_return(false)
      expect(user.need_two_factor_authentication?(request)).to be_falsey
    end
  end

  context '#password' do
    it 'errors if password is same as current password' do
      user = create(:user)
      user.password = MAX_GOOD_PASSWORD
      user.save

      expect(user.errors.first).
        to eq([:password, I18n.t('errors.messages.equal_to_current_password')])
    end

    it 'errors if password is blank' do
      user = create(:user)
      user.password = ''
      user.save

      expect(user.errors.first).to eq([:password, "can't be blank"])
    end

    it 'errors if password_confirmation is blank' do
      user = build(:user, password: 'ValidPass!!00', password_confirmation: '')
      user.save

      expect(user.errors.first).
        to eq([:password_confirmation, 'does not match password'])
      expect(user).to_not be_valid
    end

    it 'errors if password_confirmation does not mach password' do
      user = create(:user)
      user.password = 'newValidPass!!00'
      user.password_confirmation = 'doesnotmatch'
      user.save

      expect(user.errors.first).
        to eq([:password_confirmation, 'does not match password'])
    end

    it 'errors if both password and password_confirmation are blank' do
      user = build(:user, password: '', password_confirmation: '')
      user.save

      expect(user.errors.first).
        to eq([:password, "can't be blank"])
      expect(user).to_not be_valid
    end

    it 'is valid when password_confirmation matches password' do
      user = create(:user)
      user.password = 'newValidPass!!00'
      user.password_confirmation = 'newValidPass!!00'
      user.save

      expect(user).to be_valid
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

  context 'exclude old passwords' do
    # A note about password re-use (adelevie):
    # config/initializers/devise.rb currently has deny_old_passwords set to 8
    # devise_security_extensions, which implements all this, counts the 8 in
    # the archive plus the most recent password. Effectively, this means that
    # the last nine passwords cannot be used.

    let(:old_password)  { 'VeryUnique567&@' }
    let(:new_password)  { 't3hNewestLeaf$' }
    let(:eight_passwords) do
      Array.new(8) do |i|
        "#{old_password}-#{i}"
      end
    end
    let(:nine_passwords) do
      Array.new(9) do |i|
        "#{old_password}-#{i}"
      end
    end

    let(:user) { create(:user, password: old_password, password_confirmation: old_password) }

    it 'produces errors if an old password is reused' do
      user.password = new_password
      user.password_confirmation = new_password
      user.save

      user.password = old_password
      user.password_confirmation = old_password
      user.save

      expect(user.errors.any?).to be_truthy
      expect(user).to be_invalid
    end

    it 'produces an error if a password was used within 8 changes ago' do
      eight_passwords.each do |password|
        user.password = password
        user.password_confirmation = password
        user.save
      end

      user.password = old_password
      user.password_confirmation = old_password
      user.save

      expect(user.errors.any?).to be_truthy
      expect(user).to be_invalid
    end

    it 'does not produce an error if a password is used more than 9 changes ago' do
      nine_passwords.each do |password|
        user.password = password
        user.password_confirmation = password
        user.save
      end

      user.password = old_password
      user.password_confirmation = old_password
      user.save

      expect(user.errors.any?).to be_falsey
      expect(user).to be_valid
    end
  end

  describe '#log' do
    it 'sends the message to the Rails info logger' do
      user = create(:user)
      expect(Rails.logger).to receive(:info).
        with("[#{user.uuid}] [Hello world]")

      user.log('Hello world')
    end
  end

  context 'when identities are present' do
    let(:user) { create(:user, :signed_up) }
    let(:active_identity) do
      Identity.create(service_provider: 'entity_id', last_authenticated_at: Time.current - 1.hour)
    end
    let(:inactive_identity) do
      Identity.create(service_provider: 'entity_id', last_authenticated_at: nil)
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
        last_authenticated_at: Time.current - 1.hour
      )
      user.identities << Identity.create(
        service_provider: 'last',
        last_authenticated_at: Time.current
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

  describe '.reset_account' do
    let(:user) { create(:user, :signed_up) }

    it 'updates reset_requested_at to nil' do
      user.reset_account

      expect(user.reload.reset_requested_at).to be_nil
    end
  end

  describe '#last_quizzed identity' do
    let(:user) { create(:user, :signed_up) }

    context 'when the most recent identity is active and has started a quiz' do
      it 'returns the most recent identity' do
        user.identities.create(
          service_provider: 'first',
          last_authenticated_at: nil,
          quiz_started: true,
          updated_at: 5.seconds.ago
        )
        user.identities.create(
          service_provider: 'last',
          last_authenticated_at: Time.current,
          quiz_started: true,
          updated_at: Time.current
        )

        expect(user.last_quizzed_identity.service_provider).to eq('last')
      end
    end

    context 'when the most recent identity is inactive and has started a quiz' do
      it 'returns the most recent identity' do
        user.identities.create(
          service_provider: 'first',
          last_authenticated_at: 5.seconds.ago,
          quiz_started: true,
          updated_at: 5.seconds.ago
        )
        user.identities.create(
          service_provider: 'last',
          last_authenticated_at: nil,
          quiz_started: true,
          updated_at: Time.current
        )

        expect(user.last_quizzed_identity.service_provider).to eq('last')
      end
    end

    context 'when none of the identities have started a quiz' do
      it 'does not return any identity' do
        user.identities.create(
          service_provider: 'first',
          last_authenticated_at: nil,
          quiz_started: false,
          updated_at: 5.seconds.ago
        )
        user.identities.create(
          service_provider: 'last',
          last_authenticated_at: Time.current,
          quiz_started: false,
          updated_at: Time.current
        )

        expect(user.last_quizzed_identity).to be_nil
      end
    end
  end

  describe '#needs_idv?' do
    context 'when user does not have an ial_token' do
      it 'returns false' do
        user = build_stubbed(:user)

        expect(user.needs_idv?).to eq false
      end
    end

    context 'when user has an ial_token but has hard failed' do
      it 'returns false' do
        user = build_stubbed(:user, ial_token: 'foo', idp_hard_fail: true)

        expect(user.needs_idv?).to eq false
      end
    end

    context 'when user has an ial_token but has passed' do
      it 'returns false' do
        user = build_stubbed(:user, ial_token: 'foo', ial: 'IA3')

        expect(user.needs_idv?).to eq false
      end
    end

    context 'when user has an ial_token and has neither passed nor hard failed' do
      it 'returns false' do
        user = build_stubbed(:user, ial_token: 'foo')

        expect(user.needs_idv?).to eq true
      end
    end
  end

  describe '#send_two_factor_authentication_code' do
    it 'calls UserOtpSender#send_otp' do
      user = build_stubbed(:user)
      otp_sender = instance_double(UserOtpSender)

      expect(UserOtpSender).to receive(:new).with(user).and_return(otp_sender)
      expect(otp_sender).to receive(:send_otp)

      user.send_two_factor_authentication_code
    end
  end

  describe 'ial_token uniqueness' do
    it 'enforces uniqueness of ial_token but allows nil value' do
      user = build(:user)

      expect(user).to validate_uniqueness_of(:ial_token).allow_nil
    end
  end

  describe 'OTP length' do
    it 'uses Devise setting when set' do
      allow(Devise).to receive(:otp_length).and_return(10)
      user = build_stubbed(:user, otp_secret_key: 'lzmh6ekrnc5i6aaq')

      expect(user.otp_code.length).to eq 10
    end

    it 'defaults to 6 when Devise setting is not set' do
      allow(Devise).to receive(:otp_length).and_return(nil)
      user = build_stubbed(:user, otp_secret_key: 'lzmh6ekrnc5i6aaq')

      expect(user.otp_code.length).to eq 6
    end
  end
end
