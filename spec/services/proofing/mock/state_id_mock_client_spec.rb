require 'rails_helper'

RSpec.describe Proofing::Mock::StateIdMockClient do
  describe '#proof' do
    let(:applicant) { Idp::Constants::MOCK_IDV_APPLICANT_WITH_SSN.merge(uuid: '1234-abcd') }
    let(:transaction_id) { 'state-id-mock-transaction-id-456' }

    subject { described_class.new }

    context 'with good info' do
      it 'returns a passing result' do
        result = subject.proof(applicant)

        expect(result.success?).to eq(true)
        expect(result.errors).to eq({})
        expect(result.transaction_id).to eq(transaction_id)
        expect(result.to_h).to eq(
          success: true,
          errors: {},
          exception: nil,
          timed_out: false,
          transaction_id: transaction_id,
          vendor_name: 'StateIdMock',
        )
      end
    end

    context 'with info that triggers a failure to match' do
      it 'returns a failed to match result' do
        applicant[:state_id_number] = '00000000'

        result = subject.proof(applicant)

        expect(result.success?).to eq(false)
        expect(result.errors).to eq(state_id_number: ['The state ID number could not be verified'])
        expect(result.transaction_id).to eq(transaction_id)
        expect(result.to_h).to eq(
          success: false,
          errors: {
            state_id_number: ['The state ID number could not be verified'],
          },
          exception: nil,
          timed_out: false,
          transaction_id: transaction_id,
          vendor_name: 'StateIdMock',
        )
      end
    end

    context 'with info that triggers an error' do
      it 'returns an error result' do
        applicant[:state_id_number] = 'mvatimeout'

        result = subject.proof(applicant)

        expect(result.success?).to eq(false)
        expect(result.errors).to eq({})
        expect(result.transaction_id).to eq(transaction_id)
        expect(result.to_h).to match(
          success: false,
          errors: {},
          exception: an_instance_of(Proofing::TimeoutError),
          timed_out: true,
          transaction_id: transaction_id,
          vendor_name: 'StateIdMock',
        )
      end
    end
  end
end
