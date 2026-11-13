require 'rails_helper'

RSpec.describe ProofingAgent::InstantVerify::ResolutionFailureBypass do
  let(:vendor_name) { 'lexisnexis:instant_verify' }
  let(:resolution_success) { false }
  let(:resolution_exception) { nil }
  let(:resolution_errors) do
    {
      InstantVerify: {
        'ProductType' => 'InstantVerify',
        'ProductStatus' => 'fail',
        'Items' => [{ 'ItemName' => 'DOBFullVerified', 'ItemStatus' => 'fail' }],
      },
    }
  end
  let(:resolution_result) do
    Proofing::Resolution::Result.new(
      success: resolution_success,
      errors: resolution_errors,
      exception: resolution_exception,
      vendor_name: vendor_name,
      transaction_id: 'resolution-tx',
      vendor_workflow: 'workflow',
    )
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

    it 'returns the original result' do
      expect(bypass.bypassed_resolution_result).to equal(resolution_result)
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

      it 'checks the error codes of the resolution result' do
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

    context 'when the error code checker does not allow a bypass' do
      let(:checker_result) { false }

      it_behaves_like 'a result that is not bypassed'
    end

    context 'when the resolution result already succeeded' do
      let(:resolution_success) { true }

      it_behaves_like 'a result that is not bypassed without consulting the error code checker'
    end

    context 'when the vendor is not Instant Verify' do
      let(:vendor_name) { 'ResolutionMock' }

      it_behaves_like 'a result that is not bypassed without consulting the error code checker'
    end

    context 'when the resolution result is ResolutionCannotPass' do
      let(:vendor_name) { 'ResolutionCannotPass' }

      it_behaves_like 'a result that is not bypassed without consulting the error code checker'
    end

    context 'when the resolution result has an exception' do
      let(:resolution_exception) { RuntimeError.new('timeout') }

      it_behaves_like 'a result that is not bypassed without consulting the error code checker'
    end
  end

  describe '#bypassed_resolution_result' do
    subject(:result) { bypass.bypassed_resolution_result }

    it 'returns a successful copy of the resolution result' do
      expect(result).to be_success
      expect(result).not_to equal(resolution_result)
      expect(result.to_h).to eq(resolution_result.to_h.merge(success: true))
    end

    it 'keeps the original errors' do
      expect(result.errors).to eq(resolution_errors)
    end

    it 'does not mutate the original resolution result' do
      expect { result }.not_to change { resolution_result.success? }.from(false)
    end
  end
end
