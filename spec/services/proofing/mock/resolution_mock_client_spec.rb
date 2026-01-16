require 'rails_helper'

RSpec.describe Proofing::Mock::ResolutionMockClient do
  let(:applicant) { Idp::Constants::MOCK_IDV_APPLICANT_WITH_SSN.merge(uuid: '1234-abcd') }

  subject { described_class.new }

  let(:expected_success) { true }
  let(:expected_errors) { {} }
  let(:expected_exception) { nil }
  let(:expected_timed_out) { false }
  let(:expected_reference) { 'aaa-bbb-ccc' }
  let(:expected_transaction_id) { 'resolution-mock-transaction-id-123' }
  let(:expected_result) do
    {
      success: expected_success,
      errors: expected_errors,
      exception: expected_exception,
      timed_out: expected_timed_out,
      reference: expected_reference,
      reason_codes: {},
      source_attribution: [],
      transaction_id: expected_transaction_id,
      vendor_id: nil,
      vendor_name: 'ResolutionMock',
      can_pass_with_additional_verification: false,
      attributes_requiring_additional_verification: [],
      vendor_workflow: nil,
      verified_attributes: nil,
    }
  end

  describe '#proof' do
    context 'with a passing applicant' do
      it 'returns a passed result' do
        result = subject.proof(applicant)

        expect(result.success?).to eq(expected_success)
        expect(result.errors).to eq(expected_errors)
        expect(result.reference).to eq(expected_reference)
        expect(result.transaction_id).to eq(expected_transaction_id)
        expect(result.to_h).to eq(expected_result)
      end
    end

    context 'with a first name that does not match' do
      let(:expected_success) { false }
      let(:expected_errors) { { first_name: ['Unverified first name.'] } }

      it 'returns a proofing failed result' do
        applicant[:first_name] = 'Bad'

        result = subject.proof(applicant)

        expect(result.success?).to eq(expected_success)
        expect(result.errors).to eq(expected_errors)
        expect(result.to_h).to eq(expected_result)
      end
    end

    context 'with an SSN that does not match' do
      let(:expected_success) { false }
      let(:expected_errors) { { ssn: ['Unverified SSN.'] } }

      it 'returns a proofing failed result' do
        applicant[:ssn] = '555-55-5555'

        result = subject.proof(applicant)

        expect(result.success?).to eq(expected_success)
        expect(result.errors).to eq(expected_errors)
        expect(result.to_h).to eq(expected_result)
      end
    end

    context 'with a zipcode that does not match' do
      let(:expected_success) { false }
      let(:expected_errors) { { zipcode: ['Unverified ZIP code.'] } }

      it 'returns a proofing failed result' do
        applicant[:zipcode] = '00000'

        result = subject.proof(applicant)

        expect(result.success?).to eq(expected_success)
        expect(result.errors).to eq(expected_errors)
        expect(result.to_h).to eq(expected_result)
      end
    end

    context 'with a simulated failed to contact by first name' do
      let(:expected_success) { false }
      let(:expected_exception) { RuntimeError.new('Failed to contact proofing vendor') }
      it 'returns an unsuccessful result with exception' do
        applicant[:first_name] = 'Fail'

        result = subject.proof(applicant)

        expect(result.success?).to eq(expected_success)
        expect(result.errors).to eq(expected_errors)
        expect(result.to_h).to eq(expected_result)
      end
    end

    context 'with a simulated failed to contact by SSN' do
      let(:expected_success) { false }
      let(:expected_exception) { RuntimeError.new('Failed to contact proofing vendor') }

      it 'returns an unsuccessful result with exception' do
        applicant[:ssn] = '000000000'

        result = subject.proof(applicant)

        expect(result.success?).to eq(expected_success)
        expect(result.errors).to eq(expected_errors)
        expect(result.to_h).to eq(expected_result)
      end
    end

    context 'with a simulated timeout by name' do
      let(:expected_success) { false }
      let(:expected_exception) { Proofing::TimeoutError.new('resolution mock timeout') }
      let(:expected_timed_out) { true }

      it 'returns a timed out result with exception' do
        applicant[:first_name] = 'Time'

        result = subject.proof(applicant)

        expect(result.success?).to eq(expected_success)
        expect(result.errors).to eq(expected_errors)
        expect(result.to_h).to eq(expected_result)
      end
    end

    context 'with a simulated AAMVA parsing error' do
      let(:expected_success) { false }
      let(:expected_exception) do
        Proofing::Aamva::VerificationError.new('Unexpected status code in response: 504')
      end

      it 'returns a parsing error result with exception' do
        applicant[:first_name] = 'Parse'

        result = subject.proof(applicant)

        expect(result.success?).to eq(expected_success)
        expect(result.errors).to eq(expected_errors)
        expect(result.to_h).to eq(expected_result)
      end
    end
  end
end
