require 'rails_helper'

describe Idv::ProfileForm do
  let(:user) { create(:user) }
  let(:subject) { Idv::ProfileForm.new({}, user) }
  let(:profile_attrs) do
    {
      first_name: 'Some',
      last_name: 'One',
      ssn: '666661234',
      dob: '19720329',
      address1: '123 Main St',
      address2: '',
      city: 'Somewhere',
      state: 'KS',
      zipcode: '66044'
    }
  end

  it do
    is_expected.
      to validate_presence_of(:first_name).with_message(t('errors.messages.blank'))
  end

  it do
    is_expected.
      to validate_presence_of(:last_name).with_message(t('errors.messages.blank'))
  end

  it do
    is_expected.
      to validate_presence_of(:ssn).with_message(t('errors.messages.blank'))
  end

  it do
    is_expected.
      to validate_presence_of(:dob).with_message(t('idv.errors.bad_dob'))
  end

  it do
    is_expected.
      to validate_presence_of(:address1).with_message(t('errors.messages.blank'))
  end

  it do
    is_expected.
      to validate_presence_of(:city).with_message(t('errors.messages.blank'))
  end

  it do
    is_expected.
      to validate_presence_of(:state).with_message(t('errors.messages.blank'))
  end

  it do
    is_expected.
      to validate_presence_of(:zipcode).with_message(t('errors.messages.blank'))
  end

  describe 'ssn uniqueness' do
    context 'when ssn is already taken by another profile' do
      it 'is invalid' do
        diff_user = create(:user)
        profile = build(:profile, ssn: '1234', user: diff_user)
        profile.encrypt_pii('sekrit')
        profile.save!

        expect(subject.submit(profile_attrs.merge(ssn: '1234'))).to eq false
        expect(subject.errors[:ssn]).to eq [t('idv.errors.duplicate_ssn')]
      end
    end

    context 'when ssn is already taken by same profile' do
      it 'is valid' do
        profile = build(:profile, ssn: '1234', user: user)
        profile.encrypt_pii('sekrit')
        profile.save!

        expect(subject.submit(profile_attrs.merge(ssn: '1234'))).to eq true
      end
    end
  end

  describe 'dob validity' do
    context 'when dob is not parse-able' do
      it 'is invalid' do
        expect(subject.submit(profile_attrs.merge(dob: '00000000'))).to eq false
        expect(subject.errors[:dob]).to eq [t('idv.errors.bad_dob')]
      end
    end

    context 'when dob is in the future' do
      it 'is invalid' do
        expect(
          subject.submit(profile_attrs.merge(dob: (Time.zone.today + 1).strftime('%Y-%m-%d')))
        ).to eq false
        expect(subject.errors[:dob]).to eq [t('idv.errors.bad_dob')]
      end
    end
  end

  describe '#submit' do
    it 'returns true on success' do
      expect(subject.submit(profile_attrs)).to eq true
    end

    it 'returns false on failure' do
      expect(subject.submit(ssn: '1234', first_name: 'Joe')).to eq false
    end
  end
end
