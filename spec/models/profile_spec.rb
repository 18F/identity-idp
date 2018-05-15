require 'rails_helper'

describe Profile do
  let(:user) { create(:user, :signed_up, password: 'a really long sekrit') }
  let(:another_user) { create(:user, :signed_up) }
  let(:profile) { create(:profile, user: user) }
  let(:pii) do
    Pii::Attributes.new_from_hash(
      dob: '1920-01-01',
      ssn: '666-66-1234',
      first_name: 'Jane',
      last_name: 'Doe'
    )
  end
  #let(:user_access_key) { user.unlock_user_access_key(user.password) }

  it { is_expected.to belong_to(:user) }
  it { is_expected.to have_many(:usps_confirmation_codes).dependent(:destroy) }

  describe '#encrypt_pii' do
    it 'encrypts PII' do
      expect(profile.encrypted_pii).to be_nil

      profile.encrypt_pii(pii, user.password)

      expect(profile.encrypted_pii).to_not be_nil
      expect(profile.encrypted_pii).to_not match 'Jane'
      expect(profile.encrypted_pii).to_not match '666'
    end

    it 'generates new personal key' do
      expect(profile.encrypted_pii_recovery).to be_nil

      initial_personal_key = user.personal_key

      profile.encrypt_pii(pii, user.password)

      expect(profile.encrypted_pii_recovery).to_not be_nil
      expect(user.personal_key).to_not eq initial_personal_key
    end
  end

  describe '#encrypt_recovery_pii' do
    it 'generates new personal key' do
      expect(profile.encrypted_pii_recovery).to be_nil

      initial_personal_key = user.personal_key

      profile.encrypt_recovery_pii(pii)

      expect(profile.encrypted_pii_recovery).to_not be_nil
      expect(user.personal_key).to_not eq initial_personal_key
      expect(profile.personal_key).to_not eq user.personal_key
    end
  end

  describe '#decrypt_pii' do
    it 'decrypts PII' do
      expect(profile.encrypted_pii).to be_nil

      profile.encrypt_pii(pii, user.password)

      decrypted_pii = profile.decrypt_pii(user.password)

      expect(decrypted_pii).to eq pii
    end
  end

  describe '#recover_pii' do
    it 'decrypts the encrypted_pii_recovery using a personal key' do
      expect(profile.encrypted_pii_recovery).to be_nil

      profile.encrypt_pii(pii, user.password)
      personal_key = profile.personal_key

      normalized_personal_key = PersonalKeyGenerator.new(user).normalize(personal_key)

      expect(profile.recover_pii(normalized_personal_key)).to eq pii
    end
  end

  describe 'allows only one active Profile per user' do
    it 'prevents create! via ActiveRecord uniqueness validation' do
      profile.active = true
      profile.save!
      expect { Profile.create!(user_id: user.id, active: true) }.
        to raise_error(ActiveRecord::RecordInvalid)
    end

    it 'prevents save! via psql unique partial index' do
      profile.active = true
      profile.save!
      expect do
        another_profile = Profile.new(user_id: user.id, active: true)
        another_profile.save!(validate: false)
      end.to raise_error(ActiveRecord::RecordNotUnique)
    end
  end

  describe 'allows one unique SSN per user' do
    it 'allows multiple records per user if only one is active' do
      profile.active = true
      pii_attrs = Pii::Attributes.new_from_hash(ssn: '1234')
      profile.encrypt_pii(pii_attrs, user.password)
      profile.save!
      expect { create(:profile, pii: { ssn: '1234' }, user: user) }.to_not raise_error
    end

    it 'prevents save! via ActiveRecord uniqueness validation' do
      profile = Profile.new(active: true, user: user)
      profile.encrypt_pii(pii, user.password)
      profile.save!
      expect do
        another_profile = Profile.new(active: true, user: another_user)
        another_profile.encrypt_pii(pii, user.password)
        another_profile.save!
      end.to raise_error(ActiveRecord::RecordInvalid)
    end

    it 'prevents save! via psql unique partial index' do
      profile = Profile.new(active: true, user: user)
      profile.encrypt_pii(pii, user.password)
      profile.save!
      expect do
        another_profile = Profile.new(active: true, user: another_user)
        another_profile.encrypt_pii(pii, another_user.password)
        another_profile.save!(validate: false)
      end.to raise_error(ActiveRecord::RecordNotUnique)
    end
  end

  describe '#activate' do
    it 'activates current Profile, de-activates all other Profile for the user' do
      active_profile = Profile.create(user: user, active: true)
      profile.activate
      active_profile.reload
      expect(active_profile).to_not be_active
      expect(profile).to be_active
    end
  end

  describe '#deactivate' do
    it 'sets active flag to false' do
      profile = create(:profile, :active, user: user)
      profile.deactivate(:password_reset)

      expect(profile).to_not be_active
      expect(profile).to be_password_reset
    end
  end

  describe 'scopes' do
    describe '#active' do
      it 'returns only active Profiles' do
        user.profiles.create(active: false)
        user.profiles.create(active: true)
        expect(user.profiles.active.count).to eq 1
      end
    end

    describe '#verified' do
      it 'returns only verified Profiles' do
        user.profiles.create(verified_at: Time.zone.now)
        user.profiles.create(verified_at: nil)
        expect(user.profiles.verified.count).to eq 1
      end
    end
  end
end
