require 'rails_helper'

RSpec.describe Pii::AddressForm do
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

  context 'with missing required fields' do
    let(:address) { valid_address.merge(address1: nil, city: nil, state: nil, zip_code: nil) }

    it 'reports each missing field' do
      form.valid?
      expect(form.errors[:address1]).to include('cannot be blank')
      expect(form.errors[:city]).to include('cannot be blank')
      expect(form.errors[:state]).to include('cannot be blank')
      expect(form.errors[:zip_code]).to include('cannot be blank')
    end
  end

  context 'with an invalid zip_code' do
    let(:address) { valid_address.merge(zip_code: 'abc') }

    it 'reports a format error on zip_code' do
      form.valid?
      expect(form.errors[:zip_code]).to be_present
    end
  end

  context 'with a zip+4 zip_code' do
    let(:address) { valid_address.merge(zip_code: '94110-1234') }

    it 'is valid' do
      expect(form).to be_valid
    end
  end

  context 'with an invalid state code' do
    let(:address) { valid_address.merge(state: 'ZZ') }

    it 'reports an inclusion error on state' do
      form.valid?
      expect(form.errors[:state]).to include('is not a valid state code')
    end
  end

  it 'does not enforce USPS transliteration or length limits' do
    address = valid_address.merge(
      city: 'Año Nuevo',
      address1: '1 Calle del Río',
      address2: 'a' * 300,
    )
    expect(described_class.new(address: address)).to be_valid
  end
end
