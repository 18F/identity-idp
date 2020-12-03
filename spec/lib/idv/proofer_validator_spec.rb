require 'rails_helper'

describe Idv::ProoferValidator do
  let(:proofer_mock_fallback) { 'false' }

  before do
    allow(AppConfig.env).to receive(:proofer_mock_fallback).
      and_return(proofer_mock_fallback)
  end

  subject { described_class }

  describe '.validate_vendors!' do
    let(:proofer_mock_fallback) { 'false' }

    context 'without vendors configured' do
      it 'does raise' do
        expect { described_class.validate_vendors! }.to raise_error(
          LoadError,
        )
      end
    end

    context 'without vendors configured but with mock vendors enabled' do
      let(:proofer_mock_fallback) { 'true' }

      it 'does not raise' do
        expect { described_class.validate_vendors! }.to_not raise_error
      end
    end
  end
end
