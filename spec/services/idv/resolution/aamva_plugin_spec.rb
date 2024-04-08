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

  let(:supported_jurisdictions) { ['WA', 'DE', 'MT'] }

  let(:unsupported_jurisdiction) { 'OR' }

  before do
    allow(IdentityConfig.store).to receive(:aamva_supported_jurisdictions).
      and_return(supported_jurisdictions)
  end

  subject do
    described_class.new
  end

  describe '#resolve_identity' do
    context 'no state id present' do
      let(:state_id) { nil }

      it 'excuses itself' do
        next_plugin = spy
        expect(next_plugin).to receive(:call).with(
          aamva: {
            success: false,
            reason: :no_state_id,
          },
        )

        subject.resolve_identity(input:, result: result_so_far, next_plugin:)
      end
    end

    context 'state id from unsupported jurisdiction' do
      let(:state_id) do
        Idv::Resolution::StateId.from_pii_from_doc(
          Idp::Constants::MOCK_IDV_APPLICANT.merge(
            state: unsupported_jurisdiction,
          ),
        )
      end

      it 'says it will not apply' do
        next_plugin = spy
        expect(next_plugin).to receive(:call).with(
          aamva: {
            success: false,
            reason: :unsupported_jurisdiction,
          },
        )

        subject.resolve_identity(input:, result: result_so_far, next_plugin:)
      end
    end

    context 'state id from supported jurisidiction' do
    end
  end
end
