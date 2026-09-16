require 'rails_helper'

RSpec.describe Idv::PhoneVendor do
  describe '.address_verification_vendor' do
    context 'when the vendor is nil' do
      it 'returns nil' do
        expect(described_class.address_verification_vendor(nil)).to be_nil
      end
    end

    context 'when the vendor is "socure_phonerisk"' do
      let(:vendor) { 'socure_phonerisk' }

      it 'returns "socure_address"' do
        expect(described_class.address_verification_vendor(vendor)).to eq('socure_address')
      end
    end

    context 'when the vendor is "lexis_nexis_address"' do
      let(:vendor) { 'lexis_nexis_address' }

      it 'returns "lexis_nexis_address"' do
        expect(described_class.address_verification_vendor(vendor)).to eq('lexis_nexis_address')
      end
    end

    context 'when the vendor is "AddressMock"' do
      let(:vendor) { 'AddressMock' }

      it 'returns "lexis_nexis_address"' do
        expect(described_class.address_verification_vendor(vendor)).to eq('lexis_nexis_address')
      end
    end

    context 'when the vendor does not match' do
      let(:vendor) { 'not_matching' }

      it 'returns the vendor string passed in' do
        expect(described_class.address_verification_vendor(vendor)).to eq(vendor)
      end
    end
  end
end
