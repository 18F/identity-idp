require 'rails_helper'

describe Idv::ProfileForm do
  let(:password) { 'a really long sekrit' }
  let(:ssn) { '123-11-1234' }
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
      state: 'VA',
      zipcode: '66044',
      state_id_number: '123456789',
      state_id_type: 'drivers_license',
    }
  end

  describe '#submit' do
    context 'when the form is valid' do
      it 'returns a successful form response' do
        result = subject.submit(profile_attrs)
        expect(result).to be_kind_of(FormResponse)
        expect(result.success?).to eq(true)
        expect(result.errors).to be_empty
      end
    end

    context 'when the form is invalid' do
      before { profile_attrs[:dob] = nil }

      it 'returns an unsuccessful form response' do
        result = subject.submit(profile_attrs)
        expect(result).to be_kind_of(FormResponse)
        expect(result.success?).to eq(false)
        expect(result.errors).to include(:dob)
      end
    end

    context 'when the form has invalid attributes' do
      let(:profile_attrs) { super().merge(im_invalid: 'foobar') }

      it 'raises an error' do
        expect { subject.submit(profile_attrs) }.to raise_error(
          ArgumentError, 'im_invalid is an invalid profile attribute'
        )
      end
    end
  end

  describe 'presence validations' do
    it 'is invalid when required attribute is not present' do
      %i[
        first_name last_name ssn dob address1 city state zipcode
        state_id_number state_id_type
      ].each do |attr|
        subject.submit(profile_attrs.merge(attr => nil))
        expect(subject).to_not be_valid
      end
    end
  end

  describe 'ssn uniqueness' do
    context 'when ssn is already taken by another profile' do
      it 'is invalid' do
        diff_user = create(:user)
        create(:profile, pii: { ssn: ssn }, user: diff_user)

        subject.submit(profile_attrs.merge(ssn: ssn))

        expect(subject.valid?).to eq false
        expect(subject.errors[:ssn]).to eq [t('idv.errors.duplicate_ssn')]
      end

      it 'recognizes fingerprint regardless of HMAC key age' do
        diff_user = create(:user)
        create(:profile, pii: { ssn: ssn }, user: diff_user)
        rotate_hmac_key

        subject.submit(profile_attrs.merge(ssn: ssn))

        expect(subject.valid?).to eq false
        expect(subject.errors[:ssn]).to eq [t('idv.errors.duplicate_ssn')]
      end
    end

    context 'when ssn is already taken by same profile' do
      it 'is valid' do
        create(:profile, pii: { ssn: ssn }, user: user)

        subject.submit(profile_attrs.merge(ssn: ssn))

        expect(subject.valid?).to eq true
      end

      it 'recognizes fingerprint regardless of HMAC key age' do
        create(:profile, pii: { ssn: ssn }, user: user)
        rotate_hmac_key

        subject.submit(profile_attrs.merge(ssn: ssn))

        expect(subject.valid?).to eq true
      end
    end
  end

  describe 'dob validity' do
    context 'when dob is not parse-able' do
      it 'is invalid' do
        subject.submit(profile_attrs.merge(dob: '00000000'))

        expect(subject.valid?).to eq false
        expect(subject.errors[:dob]).to eq [t('idv.errors.bad_dob')]
      end
    end

    context 'when dob is in the future' do
      it 'is invalid' do
        subject.submit(profile_attrs.merge(dob: (Time.zone.today + 1).strftime('%Y-%m-%d')))

        expect(subject.valid?).to eq false
        expect(subject.errors[:dob]).to eq [t('idv.errors.bad_dob')]
      end
    end
  end

  describe 'zipcode validity' do
    it 'accepts 9 numbers with optional `-` delimiting the 5th and 6th position' do
      %w[12345 123454567 12345-1234].each do |valid_zip|
        subject.submit(profile_attrs.merge(zipcode: valid_zip))
        expect(subject.valid?).to eq true
      end
    end

    it 'populates error for :zipcode when invalid' do
      %w[1234 123Ac-1234 1234B].each do |invalid_zip|
        subject.submit(profile_attrs.merge(zipcode: invalid_zip))
        expect(subject.valid?).to eq false
        expect(subject.errors[:zipcode]).to eq [I18n.t('idv.errors.pattern_mismatch.zipcode')]
      end
    end
  end

  describe 'ssn validity' do
    it 'accepts 9 numbers with optional `-` delimiters' do
      %w[123411111 123-11-1123].each do |valid_ssn|
        subject.submit(profile_attrs.merge(ssn: valid_ssn))
        expect(subject.valid?).to eq true
      end
    end

    it 'populates errors for :ssn when invalid' do
      %w[1234 123-1-1111 abc-11-1123].each do |invalid_ssn|
        subject.submit(profile_attrs.merge(ssn: invalid_ssn))
        expect(subject.valid?).to eq false
        expect(subject.errors[:ssn]).to eq [I18n.t('idv.errors.pattern_mismatch.ssn')]
      end
    end
  end

  describe 'state id jurisdction validity' do
    it 'populates error for unsupported jurisdiction ' do
      subject.submit(profile_attrs.merge(state: 'AL'))
      expect(subject.valid?).to eq false
      expect(subject.errors[:state]).to eq [I18n.t('idv.errors.unsupported_jurisdiction')]
    end
  end

  describe 'state id type validity' do
    it 'populates error for invalid state id type ' do
      subject.submit(profile_attrs.merge(state_id_type: 'passport'))
      expect(subject.valid?).to eq false
      expect(subject.errors).to include(:state_id_type)
    end
  end
end
