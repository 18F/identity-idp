require 'rails_helper'

RSpec.describe Idv::Resolution::AamvaPlugin do
  let(:input) do
    Idv::Resolution::Input.new(
      state_id:,
    )
  end

  let(:state_id) do
    Idv::Resolution::StateId.from_pii_from_doc(
      Idp::Constants::MOCK_IDV_APPLICANT,
    )
  end

  let(:result_so_far) { {} }

  let(:supported_jurisdictions) { ['WA', 'DE', 'ND'] }

  let(:unsupported_jurisdiction) { 'OR' }

  before do
    allow(IdentityConfig.store).to receive(:aamva_supported_jurisdictions).
      and_return(supported_jurisdictions)
  end

  subject do
    described_class.new
  end

  describe '#call' do
    context 'no state id present' do
      let(:state_id) { nil }

      it 'excuses itself' do
        next_plugin = spy
        expect(next_plugin).to receive(:call).with(
          aamva: state_id_result_with(
            success: false,
            exception: :state_id_missing,
          ),
        )

        subject.call(input:, result: result_so_far, next_plugin:)
      end
    end

    context 'state id from unsupported jurisdiction' do
      let(:state_id) do
        Idv::Resolution::StateId.from_pii_from_doc(
          Idp::Constants::MOCK_IDV_APPLICANT.merge(
            state_id_jurisdiction: unsupported_jurisdiction,
          ),
        )
      end

      it 'says it will not apply' do
        next_plugin = next_plugin_expecting(
          aamva: state_id_result_with(
            success: false,
            exception: :unsupported_jurisdiction,
          ),
        )

        subject.call(input:, result: result_so_far, next_plugin:)
      end
    end

    context 'state id from supported jurisidiction' do
      before do
        allow(IdentityConfig.store).to receive(:proofer_mock_fallback).and_return(true)
      end

      it 'calls the proofer' do
        next_plugin = next_plugin_expecting(
          aamva: state_id_result_with(
            success: true,
          ),
        )

        subject.call(input:, result: result_so_far, next_plugin:)
      end

      context 'when the proofer has an exeception' do
        it 'returns a failure result'
      end

      context 'when successful AAMVA result already present' do
        let(:result_so_far) do
          {
            aamva: Proofing::StateIdResult.new(success: true),
          }
        end
        it 'does not do anything' do
          next_plugin = next_plugin_expecting(no_args)
          expect_any_instance_of(Proofing::Mock::StateIdMockClient).not_to receive(:proof)
          subject.call(input:, result: result_so_far, next_plugin:)
        end
      end

      context 'when AAMVA failure already present' do
        let(:result_so_far) do
          {
            aamva: Proofing::StateIdResult.new(success: false),
          }
        end
        it 'does not do anything' do
          next_plugin = next_plugin_expecting(no_args)
          expect_any_instance_of(Proofing::Mock::StateIdMockClient).not_to receive(:proof)
          subject.call(input:, result: result_so_far, next_plugin:)
        end
      end

      context 'when AAMVA exception already present' do
        let(:result_so_far) do
          {
            aamva: Proofing::StateIdResult.new(success: false, exception: :no_state_id),
          }
        end
        it 'makes a new proofer call' do
          next_plugin = next_plugin_expecting(
            {
              aamva: satisfy do |value|
                expect(value).to be_instance_of(Proofing::StateIdResult)
                expect(value).to have_attributes(success: true)
              end,
            },
          )
          expect_any_instance_of(Proofing::Mock::StateIdMockClient).to receive(:proof).and_call_original
          subject.call(input:, result: result_so_far, next_plugin:)
        end
      end
    end
  end

  def next_plugin_expecting(*args, **kwargs)
    next_plugin = spy
    expect(next_plugin).to receive(:call).with(*args, **kwargs)
    next_plugin
  end

  def state_id_result_with(**kwargs)
    satisfy do |value|
      expect(value).to be_instance_of(Proofing::StateIdResult)
      expect(value).to have_attributes(**kwargs)
    end
  end
end
