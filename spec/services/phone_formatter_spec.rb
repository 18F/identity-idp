require 'rails_helper'

RSpec.describe PhoneFormatter do
  describe '#format' do
    it 'formats international numbers correctly' do
      phone = '+40211234567'
      formatted_phone = PhoneFormatter.format(phone)

      expect(formatted_phone).to eq('+40 21 123 4567')
    end

    it 'formats ambiguous numbers as US' do
      phone = '2025005000'
      formatted_phone = PhoneFormatter.format(phone)

      expect(formatted_phone).to eq('+1 202-500-5000')
    end

    it 'formats U.S. numbers correctly' do
      phone = '+12025005000'
      formatted_phone = PhoneFormatter.format(phone)

      expect(formatted_phone).to eq('+1 202-500-5000')
    end

    it 'formats Canadian numbers correctly' do
      phone = '+13065550100'
      formatted_phone = PhoneFormatter.format(phone)

      expect(formatted_phone).to eq('+1 306 555 0100')
    end

    it 'uses +1 as the default international code' do
      phone = '2025005000'
      formatted_phone = PhoneFormatter.format(phone)

      expect(formatted_phone).to eq('+1 202-500-5000')
    end

    it 'uses the international code for the country specified in the country code option' do
      phone = '636023853'
      formatted_phone = PhoneFormatter.format(phone, country_code: 'MA')

      expect(formatted_phone).to eq('+212 636-023853')
    end

    it 'returns nil for nil' do
      formatted_phone = PhoneFormatter.format(nil)

      expect(formatted_phone).to be_nil
    end

    it 'returns nil for nonsense' do
      phone = '☎️📞📱📳'
      formatted_phone = PhoneFormatter.format(phone)
      expect(formatted_phone).to be_nil
    end
  end

  describe '#mask' do
    it 'masks all but the last four digits' do
      phone = '+1 703 555 1212'
      masked_phone = PhoneFormatter.mask(phone)
      expect(masked_phone).to eq('(***) ***-1212')
    end

    it 'masks all but the last four digits of formatted international numbers' do
      phone = '+212 636-023853'
      masked_phone = PhoneFormatter.mask(phone)
      expect(masked_phone).to eq('****-**3853')
    end

    it 'returns an empty string for a blank phone number' do
      phone = '    '
      masked_phone = PhoneFormatter.mask(phone)
      expect(masked_phone).to eq('')
    end
  end
end
