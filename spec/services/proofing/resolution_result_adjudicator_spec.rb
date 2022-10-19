require 'rails_helper'

RSpec.describe Proofing::ResolutionResultAdjudicator do
  let(:resolution_success) { true }
  let(:can_pass_with_additional_verification) { false }
  let(:attributes_requiring_additional_verification) { [] }
  let(:resolution_result) do
    Proofing::ResolutionResult.new(
      success: resolution_success,
      errors: {},
      exception: nil,
      vendor_name: 'test-resolution-vendor',
      failed_result_can_pass_with_additional_verification: can_pass_with_additional_verification,
      attributes_requiring_additional_verification: attributes_requiring_additional_verification,
    )
  end

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

  subject do
    described_class.new(
      resolution_result: resolution_result,
      state_id_result: state_id_result,
      should_proof_state_id: should_proof_state_id,
    )
  end

  describe '#adjudicated_result' do
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
  end
end
