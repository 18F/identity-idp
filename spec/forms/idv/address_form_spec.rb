require 'rails_helper'

RSpec.describe Idv::AddressForm do
  let(:initial_address) do
    Pii::Address.new(
      address1: '123 Main St',
      address2: '',
      city: 'Testertown',
      state: 'TX',
      zipcode: '11111',
    )
  end

  let(:params) do
    {
      address1: '456 Other St',
      address2: 'Apt 1',
      city: 'McTestville',
      state: 'IL',
      zipcode: '22222',
    }
  end

  it 'is initialized with values from the hash in the initializer' do
    address_form = Idv::AddressForm.new(initial_address)
    expect(address_form.address1).to eq('123 Main St')
    expect(address_form.address2).to eq('')
    expect(address_form.city).to eq('Testertown')
    expect(address_form.state).to eq('TX')
    expect(address_form.zipcode).to eq('11111')
  end

  describe '#submit' do
    context 'with valid params' do
      it 'returns a successful result' do
        result = Idv::AddressForm.new(initial_address).submit(params)

        expect(result.success?).to eq(true)
      end
    end

    context 'with a malformed param' do
      it 'returns an error result' do
        params[:zipcode] = 'this is not a valid zipcde'

        result = Idv::AddressForm.new(initial_address).submit(params)

        expect(result.success?).to eq(false)
        expect(result.errors[:zipcode]).to be_present
      end
    end

    context 'with a missing params' do
      it 'returns an error result' do
        params.delete(:zipcode)

        result = Idv::AddressForm.new(initial_address).submit(params)

        expect(result.success?).to eq(false)
        expect(result.errors[:zipcode]).to be_present
      end
    end
  end
end
