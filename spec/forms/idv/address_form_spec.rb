require 'rails_helper'

RSpec.describe Idv::AddressForm do
  let(:pii) do
    {
      first_name: 'Test',
      last_name: 'McTesterson',
      address1: '123 Main St',
      address2: nil,
      city: 'Testertown',
      state: 'TX',
      zipcode: '11111',
    }
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
    address_form = Idv::AddressForm.new(pii)
    expect(address_form.address1).to eq('123 Main St')
    expect(address_form.address2).to eq(nil)
    expect(address_form.city).to eq('Testertown')
    expect(address_form.state).to eq('TX')
    expect(address_form.zipcode).to eq('11111')
  end

  describe '#submit' do
    context 'with valid params' do
      it 'returns a successful result' do
        result = Idv::AddressForm.new(pii).submit(params)

        expect(result.success?).to eq(true)
        expect(result.extra[:address_edited]).to eq(true)
      end
    end

    context 'with a malformed param' do
      it 'returns an error result' do
        params[:zipcode] = 'this is not a valid zipcde'

        result = Idv::AddressForm.new(pii).submit(params)

        expect(result.success?).to eq(false)
        expect(result.errors[:zipcode]).to be_present
      end
    end

    context 'with a missing params' do
      it 'returns an error result' do
        params.delete(:zipcode)

        result = Idv::AddressForm.new(pii).submit(params)

        expect(result.success?).to eq(false)
        expect(result.errors[:zipcode]).to be_present
      end
    end

    context 'the user submits the same address that is in the pii' do
      it 'does not set `address_edited` to true' do
        params = pii.slice(:address1, :address2, :city, :state, :zipcode)

        result = Idv::AddressForm.new(pii).submit(params)

        expect(result.success?).to eq(true)
        expect(result.extra[:address_edited]).to eq(false)
      end
    end
  end
end
