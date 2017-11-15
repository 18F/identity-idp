require 'rails_helper'

describe Idv::AddressDeliveryMethodForm do
  subject { Idv::AddressDeliveryMethodForm.new }

  describe '#submit' do
    context 'when delivery method is phone' do
      it 'submits without error' do
        response = subject.submit(address_delivery_method: 'phone')

        expect(response).to be_a(FormResponse)
        expect(response.success?).to eq(true)
      end
    end

    context 'when delivery method is usps' do
      it 'submits without error' do
        response = subject.submit(address_delivery_method: 'usps')

        expect(response).to be_a(FormResponse)
        expect(response.success?).to eq(true)
      end
    end

    context 'when delivery method is invalid' do
      it 'submits with error' do
        response = subject.submit(address_delivery_method: 'nonsense')

        expect(response).to be_a(FormResponse)
        expect(response.success?).to eq(false)
      end
    end

    context 'when delivery method is blank' do
      it 'submits with error' do
        response = subject.submit(address_delivery_method: '')

        expect(response).to be_a(FormResponse)
        expect(response.success?).to eq(false)
      end
    end
  end
end
