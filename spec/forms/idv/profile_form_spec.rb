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
        create(:profile, pii: { ssn: ssn }, user: diff_user)

        result = {
          success: false,
          errors: { ssn: [t('idv.errors.duplicate_ssn')] }
        }

        expect(subject.submit(profile_attrs.merge(ssn: ssn))).to eq result
        expect(subject.errors[:ssn]).to eq [t('idv.errors.duplicate_ssn')]
      end

      it 'recognizes fingerprint regardless of HMAC key age' do
        diff_user = create(:user)
        create(:profile, pii: { ssn: ssn }, user: diff_user)

        rotate_hmac_key

        result = {
          success: false,
          errors: { ssn: [t('idv.errors.duplicate_ssn')] }
        }

        expect(subject.submit(profile_attrs.merge(ssn: ssn))).to eq result
        expect(subject.errors[:ssn]).to eq [t('idv.errors.duplicate_ssn')]
      end
    end

    context 'when ssn is already taken by same profile' do
      it 'is valid' do
        create(:profile, pii: { ssn: ssn }, user: user)

        result = {
          success: true,
          errors: {}
        }

        expect(subject.submit(profile_attrs.merge(ssn: ssn))).to eq result
      end

      it 'recognizes fingerprint regardless of HMAC key age' do
        create(:profile, pii: { ssn: ssn }, user: user)

        rotate_hmac_key

        result = {
          success: true,
          errors: {}
        }

        expect(subject.submit(profile_attrs.merge(ssn: ssn))).to eq result
      end
    end
  end

  describe 'dob validity' do
    context 'when dob is not parse-able' do
      it 'is invalid' do
        result = {
          success: false,
          errors: { dob: [t('idv.errors.bad_dob')] }
        }

        expect(subject.submit(profile_attrs.merge(dob: '00000000'))).to eq result
        expect(subject.errors[:dob]).to eq [t('idv.errors.bad_dob')]
      end
    end

    context 'when dob is in the future' do
      it 'is invalid' do
        result = {
          success: false,
          errors: { dob: [t('idv.errors.bad_dob')] }
        }

        expect(
          subject.submit(profile_attrs.merge(dob: (Time.zone.today + 1).strftime('%Y-%m-%d')))
        ).to eq result
        expect(subject.errors[:dob]).to eq [t('idv.errors.bad_dob')]
      end
    end
  end

  describe 'zipcode validity' do
    it 'accepts 9 numbers with optional `-` delimiting the 5th and 6th position' do
      result = {
        success: true,
        errors: {}
      }

      %w(12345 123454567 12345-1234).each do |valid_zip|
        expect(
          subject.submit(profile_attrs.merge(zipcode: valid_zip))
        ).to eq result
      end
    end

    it 'populates error for :zipcode when invalid' do
      %w(1234 123Ac-1234 1234B).each do |invalid_zip|
        subject.submit(profile_attrs.merge(zipcode: invalid_zip))
        expect(subject.errors[:zipcode]).to eq [I18n.t('idv.errors.pattern_mismatch.zipcode')]
      end
    end
  end

  describe 'ssn validity' do
    it 'accepts 9 numbers with optional `-` delimiters' do
      result = {
        success: true,
        errors: {}
      }

      %w(123411111 123-11-1123).each do |valid_ssn|
        expect(
          subject.submit(profile_attrs.merge(ssn: valid_ssn))
        ).to eq result
      end
    end

    it 'populates errors for :ssn when invalid' do
      %w(1234 123-1-1111 abc-11-1123).each do |invalid_ssn|
        subject.submit(profile_attrs.merge(ssn: invalid_ssn))
        expect(subject.errors[:ssn]).to eq [I18n.t('idv.errors.pattern_mismatch.ssn')]
      end
    end
  end

  describe '#submit' do
    it 'returns true on success' do
      result = {
        success: true,
        errors: {}
      }

      expect(subject.submit(profile_attrs)).to eq result
    end

    it 'returns false on failure' do
      result = {
        success: false,
        errors: {
          last_name: [t('errors.messages.missing_field')],
          dob: [t('idv.errors.bad_dob')],
          address1: [t('errors.messages.missing_field')],
          city: [t('errors.messages.missing_field')],
          state: [t('errors.messages.missing_field')],
          zipcode: [t('errors.messages.missing_field')]
        }
      }

      expect(subject.submit(ssn: ssn, first_name: 'Joe')).to eq result
    end
  end
end
