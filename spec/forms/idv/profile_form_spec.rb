require 'rails_helper'

describe Idv::ProfileForm do
  let(:password) { 'a really long sekrit' }
  let(:user) { create(:user, password: password) }
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

  describe 'presence validations' do
    it 'is invalid when required attribute is not present' do
      [:first_name, :last_name, :ssn, :dob, :address1, :city, :state, :zipcode].each do |attr|
        subject.submit(profile_attrs.merge(attr => nil))
        expect(subject).to_not be_valid
      end
    end
  end

  describe 'ssn uniqueness' do
    context 'when ssn is already taken by another profile' do
      it 'is invalid' do
        diff_user = create(:user)
        create(:profile, pii: { ssn: '1234' }, user: diff_user)

        expect(subject.submit(profile_attrs.merge(ssn: '1234'))).to eq false
        expect(subject.errors[:ssn]).to eq [t('idv.errors.duplicate_ssn')]
      end

      it 'recognizes fingerprint regardless of HMAC key age' do
        diff_user = create(:user)
        create(:profile, pii: { ssn: '1234' }, user: diff_user)

        rotate_hmac_key

        expect(subject.submit(profile_attrs.merge(ssn: '1234'))).to eq false
        expect(subject.errors[:ssn]).to eq [t('idv.errors.duplicate_ssn')]
      end
    end

    context 'when ssn is already taken by same profile' do
      it 'is valid' do
        create(:profile, pii: { ssn: '1234' }, user: user)

        expect(subject.submit(profile_attrs.merge(ssn: '1234'))).to eq true
      end

      it 'recognizes fingerprint regardless of HMAC key age' do
        create(:profile, pii: { ssn: '1234' }, user: user)

        rotate_hmac_key

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
