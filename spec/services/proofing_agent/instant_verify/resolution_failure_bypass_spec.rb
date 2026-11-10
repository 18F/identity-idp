require 'rails_helper'

RSpec.describe ProofingAgent::InstantVerify::ResolutionFailureBypass do
  let(:vendor_name) { 'lexisnexis:instant_verify' }
  let(:resolution_success) { false }
  let(:resolution_exception) { nil }
  let(:residential_address_stage) { { success: true, vendor_name: vendor_name } }
  let(:resolution_errors) do
    {
      InstantVerify: {
        'ProductType' => 'InstantVerify',
        'ProductStatus' => 'fail',
        'Items' => [{ 'ItemName' => 'DOBFullVerified', 'ItemStatus' => 'fail' }],
      },
    }
  end
  let(:stages) do
    {
      resolution: {
        success: resolution_success,
        vendor_name: vendor_name,
        exception: resolution_exception,
        errors: resolution_errors,
      },
      residential_address: residential_address_stage,
      phone_precheck: { success: true, vendor_name: 'AddressMock' },
    }.compact
  end
  let(:resolution_result) do
    {
      success: false,
      errors: resolution_errors,
      context: {
        resolution_adjudication_reason: 'fail_resolution_skip_state_id',
        stages: stages,
      },
    }
  end
  let(:checker_result) { true }
  let(:checker) do
    instance_double(ProofingAgent::InstantVerify::BypassErrorCodeChecker, call: checker_result)
  end

  subject(:bypass) { described_class.new(resolution_result:) }

  before do
    allow(ProofingAgent::InstantVerify::BypassErrorCodeChecker).to receive(:new).and_return(checker)
  end

  shared_examples 'a result that is not bypassed' do
    it 'is not bypassable' do
      expect(bypass.bypassable?).to eq(false)
    end

    it 'returns the resolution result unchanged' do
      expect(bypass.call).to eq(resolution_result)
    end
  end

  shared_examples 'a result that is not bypassed without consulting the error code checker' do
    it_behaves_like 'a result that is not bypassed'

    it 'does not check the error codes' do
      bypass.bypassable?

      expect(ProofingAgent::InstantVerify::BypassErrorCodeChecker).not_to have_received(:new)
    end
  end

  describe '#bypassable?' do
    context 'when Instant Verify failed only on bypassable checks' do
      it 'returns true' do
        expect(bypass.bypassable?).to eq(true)
      end

      it 'checks the error codes of the resolution stage' do
        bypass.bypassable?

        expect(ProofingAgent::InstantVerify::BypassErrorCodeChecker)
          .to have_received(:new).with(errors: resolution_errors)
      end
    end

    described_class::VENDOR_NAMES.each do |instant_verify_vendor_name|
      context "when the vendor is #{instant_verify_vendor_name}" do
        let(:vendor_name) { instant_verify_vendor_name }

        it 'returns true' do
          expect(bypass.bypassable?).to eq(true)
        end
      end
    end

    context 'when the residential address stage is missing' do
      let(:residential_address_stage) { nil }

      it 'returns true' do
        expect(bypass.bypassable?).to eq(true)
      end
    end

    context 'when the error code checker does not allow a bypass' do
      let(:checker_result) { false }

      it_behaves_like 'a result that is not bypassed'
    end

    context 'when the resolution result is nil' do
      let(:resolution_result) { nil }

      it_behaves_like 'a result that is not bypassed without consulting the error code checker'
    end

    context 'when the resolution result is empty' do
      let(:resolution_result) { {} }

      it_behaves_like 'a result that is not bypassed without consulting the error code checker'
    end

    context 'when the resolution result has no context' do
      let(:resolution_result) { { success: false } }

      it_behaves_like 'a result that is not bypassed without consulting the error code checker'
    end

    context 'when the resolution result has no resolution stage' do
      let(:stages) { { phone_precheck: { success: true } } }

      it_behaves_like 'a result that is not bypassed without consulting the error code checker'
    end

    context 'when the resolution stage already succeeded' do
      let(:resolution_success) { true }

      it_behaves_like 'a result that is not bypassed without consulting the error code checker'
    end

    context 'when the vendor is not Instant Verify' do
      let(:vendor_name) { 'ResolutionMock' }

      it_behaves_like 'a result that is not bypassed without consulting the error code checker'
    end

    context 'when the resolution stage has an exception' do
      let(:resolution_exception) { 'timeout' }

      it_behaves_like 'a result that is not bypassed without consulting the error code checker'
    end

    context 'when the residential address stage failed' do
      let(:residential_address_stage) { { success: false, vendor_name: vendor_name } }

      it_behaves_like 'a result that is not bypassed without consulting the error code checker'
    end
  end

  describe '#call' do
    subject(:result) { bypass.call }

    it 'marks the result as successful' do
      expect(result[:success]).to eq(true)
    end

    it 'sets the adjudication reason' do
      expect(result.dig(:context, :resolution_adjudication_reason)).to eq('instant_verify_bypass')
    end

    it 'marks the resolution stage as successful and bypassed' do
      expect(result.dig(:context, :stages, :resolution)).to include(success: true, bypassed: true)
    end

    it 'keeps the original errors' do
      expect(result[:errors]).to eq(resolution_errors)
      expect(result.dig(:context, :stages, :resolution, :errors)).to eq(resolution_errors)
    end

    it 'does not change the other stages' do
      expect(result.dig(:context, :stages, :residential_address)).to eq(residential_address_stage)
      expect(result.dig(:context, :stages, :phone_precheck)).to eq(stages[:phone_precheck])
    end

    it 'does not mutate the original resolution result' do
      expect { result }.not_to change { resolution_result.deep_dup }
    end
  end
end
