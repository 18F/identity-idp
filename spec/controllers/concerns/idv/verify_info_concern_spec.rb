require 'rails_helper'

RSpec.describe Idv::VerifyInfoConcern, type: :controller do
  controller ApplicationController do
    include Idv::VerifyInfoConcern
  end

  describe 'VerificationFailures' do
    subject(:verification_failures) do
      Idv::VerifyInfoConcern::VerificationFailures.new(result:)
    end

    let(:result) do
      FormResponse.new(
        success: false,
        errors: {},
        extra: {
          proofing_results: {
            context: {
              resolution_adjudication_reason: :fail_resolution_without_state_id_coverage,
              stages:,
            },
          },
        },
      )
    end
    let(:stages) do
      {
        resolution: resolution_stage,
        threatmetrix: { success: true },
        **additional_stages,
      }
    end
    let(:resolution_stage) do
      {
        success: false,
        attributes_requiring_additional_verification: [:address],
      }
    end
    let(:additional_stages) { {} }

    context 'with the current stage data' do
      it 'aggregates failures from proofing stages' do
        expect(verification_failures.failed_stages).to eq([:resolution])
        expect(verification_failures.attributes_requiring_additional_verification).to eq([:address])
      end
    end

    context 'with the future resolution attempts array' do
      let(:additional_stages) do
        {
          resolution_attempts: [
            {
              success: false,
              attributes_requiring_additional_verification: [:ssn],
            },
          ],
        }
      end

      it 'does not treat attempts as separate proofing stages' do
        expect(verification_failures.failed_stages).to eq([:resolution])
        expect(verification_failures.attributes_requiring_additional_verification).to eq([:address])
      end
    end

    context 'when a proofing stage has no additional-verification attributes' do
      let(:resolution_stage) { { success: false } }

      it 'does not add an attribute' do
        expect(verification_failures.attributes_requiring_additional_verification).to be_empty
      end
    end

    context 'when multiple proofing stages fail' do
      let(:additional_stages) do
        {
          residential_address: {
            success: false,
            attributes_requiring_additional_verification: [:ssn],
          },
        }
      end

      it 'preserves stage and attribute order' do
        expect(verification_failures.failed_stages).to eq(
          [:resolution, :residential_address],
        )
        expect(verification_failures.attributes_requiring_additional_verification).to eq(
          [:address, :ssn],
        )
      end
    end
  end

  describe '#build_proofing_exception_list' do
    subject(:exception_list) { controller.send(:build_proofing_exception_list, stages) }

    let(:stages) do
      {
        resolution: {
          vendor_name: 'final-vendor',
          exception: resolution_exception,
        },
        threatmetrix: {
          vendor_name: 'threatmetrix',
          exception: nil,
        },
        **additional_stages,
      }
    end
    let(:resolution_exception) { 'final vendor error' }
    let(:additional_stages) { {} }

    context 'with the current stage data' do
      it 'returns exceptions from proofing stages' do
        expect(exception_list).to eq(
          resolution: {
            vendor_name: 'final-vendor',
            exception: 'final vendor error',
          },
        )
      end
    end

    context 'with the future resolution attempts array' do
      let(:additional_stages) do
        {
          resolution_attempts: [
            { vendor_name: 'first-vendor', exception: 'first vendor error' },
          ],
        }
      end

      it 'does not report attempts as proofing-stage exceptions' do
        expect(exception_list).to eq(
          resolution: {
            vendor_name: 'final-vendor',
            exception: 'final vendor error',
          },
        )
      end
    end

    context 'when no proofing stage has an exception' do
      let(:resolution_exception) { nil }

      it { is_expected.to be_nil }
    end

    context 'when stages are absent' do
      let(:stages) { nil }

      it { is_expected.to be_nil }
    end
  end
end
