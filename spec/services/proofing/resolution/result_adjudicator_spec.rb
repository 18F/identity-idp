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
  let(:double_address_verification) { false }
  let(:same_address_as_id) { 'true' }

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

  subject do
    described_class.new(
      resolution_result: resolution_result,
      residential_resolution_result: residential_resolution_result,
      state_id_result: state_id_result,
      should_proof_state_id: should_proof_state_id,
      double_address_verification: double_address_verification,
      device_profiling_result: device_profiling_result,
      same_address_as_id: same_address_as_id,
    )
  end

  describe '#adjudicated_result' do
    context 'double address verification is disabled' do
      context 'AAMVA and LexisNexis both pass' do
        it 'returns a successful response' do
          result = subject.adjudicated_result

          expect(result.success?).to eq(true)
        end
      end
      context 'LexisNexis fails with attributes covered by AAMVA response' do
        let(:resolution_success) { false }
        let(:can_pass_with_additional_verification) { true }
        let(:attributes_requiring_additional_verification) { [:dob] }
        let(:state_id_verified_attributes) { [:dob, :address] }

        it 'returns a successful response' do
          result = subject.adjudicated_result

          expect(result.success?).to eq(true)
        end
      end

      context 'LexisNexis fails with attributes not covered by AAMVA response' do
        let(:resolution_success) { false }
        let(:can_pass_with_additional_verification) { true }
        let(:attributes_requiring_additional_verification) { [:address] }
        let(:state_id_verified_attributes) { [:dob] }

        it 'returns a failed response' do
          result = subject.adjudicated_result

          expect(result.success?).to eq(false)
        end
      end

      context 'LexisNexis fails and AAMVA state is unsupported' do
        let(:should_proof_state_id) { false }
        let(:resolution_success) { false }

        it 'returns a failed response' do
          result = subject.adjudicated_result

          expect(result.success?).to eq(false)
        end
      end

      context 'LexisNexis passes and AAMVA fails' do
        let(:resolution_success) { true }
        let(:state_id_success) { false }

        it 'returns a failed response' do
          result = subject.adjudicated_result

          expect(result.success?).to eq(false)
        end
      end

      context 'Device profiling fails and everything else passes' do
        let(:device_profiling_success) { false }
        let(:device_profiling_review_status) { 'fail' }

        it 'returns a successful response including the review status' do
          result = subject.adjudicated_result

          expect(result.success?).to eq(true)

          threatmetrix_context = result.extra[:context][:stages][:threatmetrix]
          expect(threatmetrix_context[:success]).to eq(false)
          expect(threatmetrix_context[:review_status]).to eq('fail')
        end
      end

      context 'Device profiling experiences an exception' do
        let(:device_profiling_success) { false }
        let(:device_profiling_exception) { 'this is a test value' }

        it 'returns a failed response' do
          result = subject.adjudicated_result

          expect(result.success?).to eq(false)

          threatmetrix_context = result.extra[:context][:stages][:threatmetrix]
          expect(threatmetrix_context[:success]).to eq(false)
          expect(threatmetrix_context[:exception]).to eq('this is a test value')
        end
      end
    end

    context 'double address verification is enabled' do
      let(:double_address_verification) { true }
      let(:should_proof_state_id) { true }
      context 'residential address and id address are different' do
        let(:same_address_as_id) { 'false' }
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
    end
  end
end
