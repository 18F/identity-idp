require 'rails_helper'

describe Profile do
  let(:user) { create(:user, :signed_up) }
  let(:another_user) { create(:user, :signed_up) }
  let(:profile) do
    Profile.create(
      user_id: user.id
    )
  end

  subject { profile }

  it { is_expected.to belong_to(:user) }

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
      profile.save!
      expect do
        user.profiles.create(ssn: '1234')
      end.to_not raise_error
    end

    it 'prevents create! via ActiveRecord uniqueness validation' do
      profile.active = true
      profile.ssn = '1234'
      profile.save!
      expect do
        Profile.create!(user_id: another_user.id, active: true, ssn: '1234')
      end.to raise_error(ActiveRecord::RecordInvalid)
    end

    it 'prevents save! via psql unique partial index' do
      profile.active = true
      profile.ssn = '1234'
      profile.save!
      expect do
        another_profile = Profile.new(user_id: another_user.id, active: true, ssn: '1234')
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
end
