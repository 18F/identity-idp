require 'rails_helper'

describe 'shared/_address.html.slim' do
  let(:address) do
    {
      address1: '123 Fake St',
      address2: 'Apt 456',
      city: 'Washington',
      state: 'DC',
      zipcode: '21234',
    }
  end

  context 'an address' do
    it 'renders all the fields of the address' do
      render 'shared/address', address: address

      expect(rendered.split('<br>')).to eq(
        [
          '123 Fake St',
          'Apt 456',
          'Washington, DC 21234',
        ],
      )
    end
  end

  context 'without an address2' do
    let(:address) { super().merge(address2: nil) }

    it 'renders 1 fewer line break' do
      render 'shared/address', address: address

      expect(rendered.split('<br>').size).to eq(2)
    end
  end
end
