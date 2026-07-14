require 'rails_helper'

RSpec.describe Pii::PassportForm do
  let(:valid_passport) do
    {
      expiration_date: (Time.zone.today + 365).to_s,
      issue_date: '2020-01-01',
      mrz: 'P<UTOSAMPLE<<COMPANY<<<<<<<<<<<<<<<<<<<<<<<<' \
           'ACU1234P<5UTO0003067F4003065<<<<<<<<<<<<<<02',
      issuing_country_code: 'USA',
    }
  end

  subject(:form) { described_class.new(passport: passport) }

  context 'with a valid passport' do
    let(:passport) { valid_passport }

    it 'is valid' do
      expect(form).to be_valid
    end
  end

  context 'with missing required fields' do
    let(:passport) do
      valid_passport.merge(
        mrz: nil,
        issuing_country_code: nil,
      )
    end

    it 'reports each missing field' do
      form.valid?
      expect(form.errors[:mrz]).to include('cannot be blank')
      expect(form.errors[:issuing_country_code]).to include('cannot be blank')
    end
  end

  context 'with missing expiration and issue dates' do
    let(:passport) { valid_passport.merge(expiration_date: nil, issue_date: nil) }

    it 'is valid (expiration and issue dates are optional)' do
      expect(form).to be_valid
    end
  end

  context 'with an unsupported issuing country code' do
    let(:passport) { valid_passport.merge(issuing_country_code: 'XYZ') }

    it 'reports an inclusion error' do
      form.valid?
      expect(form.errors[:issuing_country_code]).to include('is not a valid issuing country code')
    end
  end

  context 'with an expired passport' do
    let(:passport) { valid_passport.merge(expiration_date: (Time.zone.today - 1).to_s) }

    it 'reports expiration error' do
      form.valid?
      expect(form.errors[:expiration_date]).to include('is expired, or near expiration')
    end
  end
end
