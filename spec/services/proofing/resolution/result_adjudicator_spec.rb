require 'rails_helper'

RSpec.describe Proofing::Resolution::ResultAdjudicator do
  let(:resolution_success) { true }
  let(:can_pass_with_additional_verification) { false }
  let(:attributes_requiring_additional_verification) { [] }
  let(:resolution_result) do
    Proofing::Resolution::Result.new(
      success: resolution_success,
      errors: {},
      exception: nil,
      vendor_name: 'test-resolution-vendor',
      failed_result_can_pass_with_additional_verification: can_pass_with_additional_verification,
      attributes_requiring_additional_verification: attributes_requiring_additional_verification,
    )
  end
  let(:residential_resolution_result) { resolution_result }

  let(:state_id_success) { true }
  let(:state_id_verified_attributes) { [] }
  let(:state_id_result) do
    Proofing::StateIdResult.new(
      success: state_id_success,
      errors: {},
      exception: nil,
      vendor_name: 'test-state-id-vendor',
      verified_attributes: state_id_verified_attributes,
    )
  end

  let(:should_proof_state_id) { true }
  let(:ipp_enrollment_in_progress) { true }
  let(:same_address_as_id) { 'false' }

  let(:device_profiling_success) { true }
  let(:device_profiling_exception) { nil }
  let(:device_profiling_review_status) { 'pass' }
  let(:device_profiling_result) do
    Proofing::DdpResult.new(
      success: device_profiling_success,
      review_status: device_profiling_review_status,
      client: 'test-device-profiling-vendor',
      exception: device_profiling_exception,
    )
  end

  let(:applicant_pii) { Idp::Constants::MOCK_IDV_APPLICANT_WITH_SSN }

  subject do
    described_class.new(
      resolution_result: resolution_result,
      residential_resolution_result: residential_resolution_result,
      state_id_result: state_id_result,
      should_proof_state_id: should_proof_state_id,
      ipp_enrollment_in_progress: ipp_enrollment_in_progress,
      device_profiling_result: device_profiling_result,
      same_address_as_id: same_address_as_id,
      applicant_pii: applicant_pii,
    )
  end

  describe '#adjudicated_result' do
    context 'residential address and id address are different' do
      context 'LexisNexis fails for the residential address' do
        let(:resolution_success) { false }
        let(:residential_resolution_result) do
          Proofing::Resolution::Result.new(
            success: resolution_success,
            errors: {},
            exception: nil,
            vendor_name: 'test-resolution-vendor',
            failed_result_can_pass_with_additional_verification:
            can_pass_with_additional_verification,
            attributes_requiring_additional_verification:
            attributes_requiring_additional_verification,
          )
        end
        it 'returns a failed response' do
          result = subject.adjudicated_result

          expect(result.success?).to eq(false)
          resolution_adjudication_reason = result.extra[:context][:resolution_adjudication_reason]
          expect(resolution_adjudication_reason).to eq(:fail_resolution_skip_state_id)
        end
      end

      context 'AAMVA fails for the id address' do
        let(:state_id_success) { false }
        it 'returns a failed response' do
          result = subject.adjudicated_result

          expect(result.success?).to eq(false)
          resolution_adjudication_reason = result.extra[:context][:resolution_adjudication_reason]
          expect(resolution_adjudication_reason).to eq(:fail_state_id)
        end
      end
    end

    describe 'biographical_info' do
      context 'the applicant PII contains one address' do
        it 'includes formatted PII' do
          result = subject.adjudicated_result

          expect(result.extra[:biographical_info]).to eq(
            state: 'MT',
            identity_doc_address_state: nil,
            state_id_jurisdiction: 'ND',
            state_id_number: '#############',
            same_address_as_id: nil,
          )
        end
      end

      context 'the applicant PII contains a residential address and document address' do
        let(:applicant_pii) { Idp::Constants::MOCK_IDV_APPLICANT_SAME_ADDRESS_AS_ID }

        it 'includes formatted PII' do
          result = subject.adjudicated_result

          expect(result.extra[:biographical_info]).to eq(
            state: 'MT',
            identity_doc_address_state: 'MT',
            state_id_jurisdiction: 'ND',
            state_id_number: '#############',
            same_address_as_id: 'true',
          )
        end
      end
    end
  end
end
