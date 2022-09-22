require 'rails_helper'

RSpec.describe Idv::InheritedProofing::Va::Mocks::Service do
  subject { described_class.new(auth_code) }
  let(:auth_code) { described_class::VALID_AUTH_CODE }

  describe '#initialize' do
    it 'sets #auth_code' do
      expect(subject.auth_code).to eq auth_code
    end
  end

  describe '#execute' do
    context 'when auth_code is valid' do
      it 'returns a Hash' do
        expect(subject.execute).to eq(described_class::PAYLOAD_HASH)
      end
    end

    context 'with auth code is invalid' do
      let(:auth_code) { "invalid-#{described_class::VALID_AUTH_CODE}" }

      it 'returns an error' do
        expect { subject.execute }.to raise_error(/auth_code is invalid/)
      end
    end
  end
end
