require 'rails_helper'

describe Profile do
  let(:user) { create(:user, :signed_up) }
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
  let(:password) { 'sekrit' }

  it { is_expected.to belong_to(:user) }

  describe '#create_with_encrypted_pii' do
    it 'creates Profile with encrypted PII' do
      profile = described_class.create_with_encrypted_pii(user, pii, password)

      expect(profile.persisted?).to eq true
      expect(profile.encrypted_pii).to_not be_nil
      expect(profile.encrypted_pii).to_not match 'Jane'
    end
  end

  describe '#plain_pii' do
    it 'allows PII attribute assignment' do
      profile.dob = '1920-01-01'
      expect(profile.dob).to eq '1920-01-01'
      expect(profile.plain_pii).to be_a Pii::Attributes
      expect(profile.plain_pii.dob).to eq('1920-01-01')
    end

    it 'disallows invalid PII attribute assignment' do
      expect { profile.foo = 'bar' }.to raise_error NoMethodError
    end
  end

  describe '#encrypt_pii' do
    it 'encrypts PII' do
      expect(profile.encrypted_pii).to be_nil

      profile.encrypt_pii(password, pii)

      expect(profile.encrypted_pii).to_not be_nil
      expect(profile.encrypted_pii).to_not match 'Jane'
      expect(profile.encrypted_pii).to_not match '666'
    end

    it 'defaults to plain_pii' do
      expect(profile.encrypted_pii).to be_nil

      profile.dob = '1920-01-01'
      profile.encrypt_pii(password)

      expect(profile.encrypted_pii).to_not be_nil
      expect(profile.encrypted_pii).to_not match '1920'
    end
  end

  describe '#decrypt_pii' do
    it 'decrypts PII' do
      expect(profile.encrypted_pii).to be_nil

      profile.encrypt_pii(password, pii)

      decrypted_pii = profile.decrypt_pii(password)

      expect(decrypted_pii).to eq pii
    end
  end

  describe 'allows only one active Profile per user' do
    it 'prevents create! via ActiveRecord uniqueness validation' do
      profile.active = true
      profile.save!
      expect do
        Profile.create!(user_id: user.id, active: true)
      end.to raise_error(ActiveRecord::RecordInvalid)
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
      profile.ssn = '1234'
      profile.encrypt_pii(password)
      profile.save!
      expect do
        another_profile = build(:profile, ssn: '1234', user: user)
        another_profile.encrypt_pii(password)
        another_profile.save!
      end.to_not raise_error
    end

    it 'prevents save! via ActiveRecord uniqueness validation' do
      profile = Profile.new(active: true, user: user, ssn: '1234')
      profile.encrypt_pii(password)
      profile.save!
      expect do
        another_profile = Profile.new(active: true, user: another_user, ssn: '1234')
        another_profile.encrypt_pii(password)
        another_profile.save!
      end.to raise_error(ActiveRecord::RecordInvalid)
    end

    it 'prevents save! via psql unique partial index' do
      profile = Profile.new(active: true, user: user, ssn: '1234')
      profile.encrypt_pii(password)
      profile.save!
      expect do
        another_profile = Profile.new(active: true, user: another_user, ssn: '1234')
        another_profile.encrypt_pii(password)
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
        user.profiles.create(verified_at: Time.current)
        user.profiles.create(verified_at: nil)
        expect(user.profiles.verified.count).to eq 1
      end
    end
  end
end
