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

      expect(formatted_phone).to eq('+1 306-555-0100')
    end

    it 'uses +1 as the default international code' do
      phone = '2025005000'
      formatted_phone = PhoneFormatter.format(phone)

      expect(formatted_phone).to eq('+1 202-500-5000')
    end

    it 'uses the international code for the country specified in the country code option' do
      cases = {
        'MA' => ['636023853', '+212 6 36 02 38 53'],
        'FR' => ['612345678', '+33 6 12 34 56 78'],
        'GB' => ['7700900123', '+44 7700 900123'],
        'DE' => ['15123456789', '+49 1512 3456789'],
        'IN' => ['9123456789', '+91 91234 56789'],
        'BR' => ['11987654321', '+55 11 98765-4321'],
      }

      cases.each do |country_code, (phone, expected_phone)|
        formatted_phone = PhoneFormatter.format(phone, country_code: country_code)

        expect(formatted_phone).to eq(expected_phone)
      end
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

    it 'masks formatted international numbers while preserving country-specific separators' do
      cases = {
        'MA' => ['636023853', '* ** ** 38 53'],
        'FR' => ['612345678', '* ** ** 56 78'],
        'GB' => ['7700900123', '**** **0123'],
        'DE' => ['15123456789', '**** ***6789'],
        'IN' => ['9123456789', '***** *6789'],
        'BR' => ['11987654321', '(**) *****-4321'],
      }

      cases.each do |country_code, (phone, expected_masked_phone)|
        formatted_phone = PhoneFormatter.format(phone, country_code: country_code)
        masked_phone = PhoneFormatter.mask(formatted_phone)

        expect(masked_phone).to eq(expected_masked_phone)
        expect(masked_phone.count('*') + masked_phone.count('0-9')).to eq(phone.length)
      end
    end

    it 'returns an empty string for a blank phone number' do
      phone = '    '
      masked_phone = PhoneFormatter.mask(phone)
      expect(masked_phone).to eq('')
    end
  end
end
