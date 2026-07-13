require 'rails_helper'

RSpec.describe Pii::UspsStrictAddressForm do
  let(:valid_address) do
    {
      address1: '1 Main St',
      address2: 'Apt 2',
      city: 'Anytown',
      state: 'CA',
      zip_code: '94110',
    }
  end

  subject(:form) { described_class.new(address: address) }

  context 'with a valid address' do
    let(:address) { valid_address }

    it 'is valid' do
      expect(form).to be_valid
    end
  end

  context 'with invalid characters in city' do
    let(:address) { valid_address.merge(city: 'Bad$City') }

    it 'reports a transliteration error on city' do
      form.valid?
      expect(form.errors[:city].join).to match(/has invalid characters/)
    end
  end

  context 'with invalid characters in address1' do
    let(:address) { valid_address.merge(address1: '1 Main St!') }

    it 'reports a transliteration error on address1' do
      form.valid?
      expect(form.errors[:address1].join).to match(/has invalid characters/)
    end
  end

  context 'with too-long fields' do
    let(:address) { valid_address.merge(address1: 'a' * 300) }

    it 'reports a length error' do
      form.valid?
      expect(form.errors[:address1].join).to match(/too long/i)
    end
  end

  it 'still applies base presence/format/state validations' do
    f = described_class.new(address: valid_address.merge(zip_code: 'abc', state: 'ZZ'))
    f.valid?
    expect(f.errors[:zip_code]).to be_present
    expect(f.errors[:state]).to include('is not a valid state code')
  end
end
