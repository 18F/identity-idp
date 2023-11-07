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
      attributes_requiring_additional_verification:,
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
  let(:double_address_verification) { true }
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

  subject do
    described_class.new(
      resolution_result:,
      residential_resolution_result:,
      state_id_result:,
      should_proof_state_id:,
      ipp_enrollment_in_progress:,
      double_address_verification:,
      device_profiling_result:,
      same_address_as_id:,
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
            attributes_requiring_additional_verification:,
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

      # rubocop:disable Layout/LineLength
      context 'Confirm adjudication works for either double_address_verification or ipp_enrollment_in_progress' do
        context 'Adjudication passes if double_address_verification is false and ipp_enrollment_in_progress is true' do
          # rubocop:enable Layout/LineLength
          let(:double_address_verification) { false }
          let(:ipp_enrollment_in_progress) { true }

          it 'returns a successful response' do
            result = subject.adjudicated_result

            expect(result.success?).to eq(true)
          end
        end
        # rubocop:disable Layout/LineLength
        context 'Adjudication passes if ipp_enrollment_in_progress is false and double_address_verification is true' do
          # rubocop:enable Layout/LineLength
          let(:double_address_verification) { true }
          let(:ipp_enrollment_in_progress) { false }

          it 'returns a successful response' do
            result = subject.adjudicated_result

            expect(result.success?).to eq(true)
          end
        end
      end
    end
  end
end
