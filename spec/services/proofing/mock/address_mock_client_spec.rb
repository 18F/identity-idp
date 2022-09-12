require 'rails_helper'

RSpec.describe Proofing::Mock::AddressMockClient do
  describe '#proof' do
    let(:transaction_id) { 'address-mock-transaction-id-123' }

    context 'with a phone number that passes' do
      it 'returns a successful result' do
        result = subject.proof(phone: '2025551000')

        expect(result.success?).to eq(true)
        expect(result.errors).to eq({})
        expect(result.transaction_id).to eq(transaction_id)
        expect(result.to_h).to eq(
          success: true,
          errors: {},
          exception: nil,
          timed_out: false,
          transaction_id: transaction_id,
          vendor_name: 'AdressMock',
        )
      end
    end

    context 'with a phone number that fails to match the user' do
      it 'returns a proofing failed result' do
        result = subject.proof(phone: '7035555555')

        expect(result.success?).to eq(false)
        expect(result.errors).to eq(phone: 'The phone number could not be verified.')
        expect(result.to_h).to eq(
          success: false,
          errors: { phone: 'The phone number could not be verified.' },
          exception: nil,
          timed_out: false,
          transaction_id: transaction_id,
          vendor_name: 'AdressMock',
        )
      end
    end

    context 'with a phone number that raises an exception' do
      it 'returns a result with an exception' do
        result = subject.proof(phone: '7035555999')

        expect(result.success?).to eq(false)
        expect(result.errors).to eq({})
        expect(result.to_h).to eq(
          success: false,
          errors: {},
          exception: RuntimeError.new('Failed to contact proofing vendor'),
          timed_out: false,
          transaction_id: transaction_id,
          vendor_name: 'AdressMock',
        )
      end
    end

    context 'with a phone number that times out' do
      it 'returns a result with a timeout exception' do
        result = subject.proof(phone: '7035555888')

        expect(result.success?).to eq(false)
        expect(result.errors).to eq({})
        expect(result.to_h).to eq(
          success: false,
          errors: {},
          exception: Proofing::TimeoutError.new('address mock timeout'),
          timed_out: true,
          transaction_id: transaction_id,
          vendor_name: 'AdressMock',
        )
      end
    end
  end
end
