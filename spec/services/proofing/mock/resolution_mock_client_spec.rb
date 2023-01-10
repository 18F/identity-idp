require 'rails_helper'

RSpec.describe Proofing::Mock::ResolutionMockClient do
  let(:applicant) { Idp::Constants::MOCK_IDV_APPLICANT_WITH_SSN.merge(uuid: '1234-abcd') }

  subject { described_class.new }

  let(:transaction_id) { 'resolution-mock-transaction-id-123' }
  let(:reference) { 'aaa-bbb-ccc' }

  describe '#proof' do
    context 'with a passing applicant' do
      it 'returns a passed result' do
        result = subject.proof(applicant)

        expect(result.success?).to eq(true)
        expect(result.errors).to eq({})
        expect(result.reference).to eq(reference)
        expect(result.transaction_id).to eq(transaction_id)
        expect(result.to_h).to eq(
          success: true,
          errors: {},
          exception: nil,
          timed_out: false,
          reference: reference,
          transaction_id: transaction_id,
          vendor_name: 'ResolutionMock',
          can_pass_with_additional_verification: false,
          attributes_requiring_additional_verification: [],
          vendor_workflow: nil,
          drivers_license_check_info: nil,
        )
      end
    end

    context 'with a first name that does not match' do
      it 'returns a proofing failed result' do
        applicant[:first_name] = 'Bad'

        result = subject.proof(applicant)

        expect(result.success?).to eq(false)
        expect(result.errors).to eq(first_name: ['Unverified first name.'])
        expect(result.to_h).to eq(
          success: false,
          errors: { first_name: ['Unverified first name.'] },
          exception: nil,
          timed_out: false,
          reference: reference,
          transaction_id: transaction_id,
          vendor_name: 'ResolutionMock',
          can_pass_with_additional_verification: false,
          attributes_requiring_additional_verification: [],
          vendor_workflow: nil,
          drivers_license_check_info: nil,
        )
      end
    end

    context 'with an SSN that does not match' do
      it 'returns a proofing failed result' do
        applicant[:ssn] = '555-55-5555'

        result = subject.proof(applicant)

        expect(result.success?).to eq(false)
        expect(result.errors).to eq(ssn: ['Unverified SSN.'])
        expect(result.to_h).to eq(
          success: false,
          errors: { ssn: ['Unverified SSN.'] },
          exception: nil,
          timed_out: false,
          reference: reference,
          transaction_id: transaction_id,
          vendor_name: 'ResolutionMock',
          can_pass_with_additional_verification: false,
          attributes_requiring_additional_verification: [],
          vendor_workflow: nil,
          drivers_license_check_info: nil,
        )
      end
    end

    context 'with a zipcode that does not match' do
      it 'returns a proofing failed result' do
        applicant[:zipcode] = '00000'

        result = subject.proof(applicant)

        expect(result.success?).to eq(false)
        expect(result.errors).to eq(zipcode: ['Unverified ZIP code.'])
        expect(result.to_h).to eq(
          success: false,
          errors: { zipcode: ['Unverified ZIP code.'] },
          exception: nil,
          timed_out: false,
          reference: reference,
          transaction_id: transaction_id,
          vendor_name: 'ResolutionMock',
          can_pass_with_additional_verification: false,
          attributes_requiring_additional_verification: [],
          vendor_workflow: nil,
          drivers_license_check_info: nil,
        )
      end
    end

    context 'with a simulated failed to contact by first name' do
      it 'returns an unsuccessful result with exception' do
        applicant[:first_name] = 'Fail'

        result = subject.proof(applicant)

        expect(result.success?).to eq(false)
        expect(result.errors).to eq({})
        expect(result.to_h).to eq(
          success: false,
          errors: {},
          exception: RuntimeError.new('Failed to contact proofing vendor'),
          timed_out: false,
          reference: reference,
          transaction_id: transaction_id,
          vendor_name: 'ResolutionMock',
          can_pass_with_additional_verification: false,
          attributes_requiring_additional_verification: [],
          vendor_workflow: nil,
          drivers_license_check_info: nil,
        )
      end
    end

    context 'with a simulated failed to contact by SSN' do
      it 'returns an unsuccessful result with exception' do
        applicant[:ssn] = '000000000'

        result = subject.proof(applicant)

        expect(result.success?).to eq(false)
        expect(result.errors).to eq({})
        expect(result.to_h).to eq(
          success: false,
          errors: {},
          exception: RuntimeError.new('Failed to contact proofing vendor'),
          timed_out: false,
          reference: reference,
          transaction_id: transaction_id,
          vendor_name: 'ResolutionMock',
          can_pass_with_additional_verification: false,
          attributes_requiring_additional_verification: [],
          vendor_workflow: nil,
          drivers_license_check_info: nil,
        )
      end
    end

    context 'with a simulated timeout by name' do
      it 'returns a timed out result with exception' do
        applicant[:first_name] = 'Time'

        result = subject.proof(applicant)

        expect(result.success?).to eq(false)
        expect(result.errors).to eq({})
        expect(result.to_h).to eq(
          success: false,
          errors: {},
          exception: Proofing::TimeoutError.new('address mock timeout'),
          timed_out: true,
          reference: reference,
          transaction_id: transaction_id,
          vendor_name: 'ResolutionMock',
          can_pass_with_additional_verification: false,
          attributes_requiring_additional_verification: [],
          vendor_workflow: nil,
          drivers_license_check_info: nil,
        )
      end
    end
  end
end
