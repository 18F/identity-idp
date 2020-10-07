require 'rails_helper'

describe Idv::Proofer do
  let(:proofer_mock_fallback) { 'false' }

  before do
    allow(Figaro.env).to receive(:proofer_mock_fallback).
      and_return(proofer_mock_fallback)
  end

  subject { described_class }

  describe '.resolution_vendor' do
    context 'with mock proofers enabled' do
      let(:proofer_mock_fallback) { 'true' }

      it 'returns the mock vendor' do
        expect(subject.resolution_vendor).to eq(ResolutionMock)
      end
    end

    context 'with mock proofers disabled' do
      before do
        class_double('LexisNexis::InstantVerify::Proofer', new: {}).as_stubbed_const
      end

      it 'returns the live vendor' do
        expect(subject.resolution_vendor).to eq(LexisNexis::InstantVerify::Proofer)
      end
    end
  end

  describe '.state_id_vendor' do
    context 'with mock proofers enabled' do
      let(:proofer_mock_fallback) { 'true' }

      it 'returns the mock vendor' do
        expect(subject.state_id_vendor).to eq(StateIdMock)
      end
    end

    context 'with mock proofers disabled' do
      before do
        class_double('Aamva::Proofer', new: {}).as_stubbed_const
      end

      it 'returns the live vendor' do
        expect(subject.state_id_vendor).to eq(Aamva::Proofer)
      end
    end
  end

  describe '.validate_vendors!' do
    let(:proofer_mock_fallback) { 'false' }

    context 'without vendors configured for each stage' do
      it 'does raise' do
        expect { described_class.validate_vendors! }.to raise_error(
          LoadError
        )
      end
    end

    context 'without vendors configured but with mock vendors enabled' do
      let(:proofer_vendors) { '["dummy:state_id"]' }
      let(:proofer_mock_fallback) { 'true' }

      it 'does not raise' do
        expect { described_class.validate_vendors! }.to_not raise_error
      end
    end
  end
end
