require 'rails_helper'

describe PhoneFormatter do
  describe '#format' do
    it 'formats international numbers correctly' do
      phone = '+404004004000'
      formatted_phone = PhoneFormatter.new.format(phone)

      expect(formatted_phone).to eq('+40 400 400 4000')
    end

    it 'formats U.S. numbers correctly' do
      phone = '+12025005000'
      formatted_phone = PhoneFormatter.new.format(phone)

      expect(formatted_phone).to eq('+1 (202) 500-5000')
    end

    it 'uses +1 as the default international code' do
      phone = '2025005000'
      formatted_phone = PhoneFormatter.new.format(phone)

      expect(formatted_phone).to eq('+1 (202) 500-5000')
    end

    it 'uses the international code for the country specified in the country code option' do
      phone = '123123123'
      formatted_phone = PhoneFormatter.new.format(phone, country_code: 'MA')

      expect(formatted_phone).to eq('+212 12 3123 123')
    end

    it 'returns nil for nil' do
      formatted_phone = PhoneFormatter.new.format(nil)

      expect(formatted_phone).to be_nil
    end

    it 'returns nil for nonsense' do
      phone = '☎️📞📱📳'
      formatted_phone = PhoneFormatter.new.format(phone)
      expect(formatted_phone).to be_nil
    end
  end
end
