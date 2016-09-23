require 'rails_helper'

describe Profile do
  let(:user) { create(:user, :signed_up) }
  let(:another_user) { create(:user, :signed_up) }
  let(:profile) { create(:profile, user: user) }

  subject { profile }

  it { is_expected.to belong_to(:user) }

  describe '#method_missing' do
    it 'allows PII attribute assignment' do
      profile.dob = '1920-01-01'

      expect(profile.dob).to eq '1920-01-01'
      expect(profile.decrypted_pii).to eq(dob: '1920-01-01')
    end

    it 'disallows invalid PII attribute assignment' do
      expect { profile.foo = 'bar' }.to raise_error NoMethodError
    end
  end

  describe 'before_save' do
    it 'encrypts decrypted_pii' do
      expect(profile.encrypted_pii).to eq nil

      profile.dob = '1920-01-01'
      profile.save

      expect(profile.encrypted_pii).to eq({ dob: '1920-01-01' }.to_json)
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
