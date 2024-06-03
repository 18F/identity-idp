require 'rails_helper'

RSpec.describe UspsInPersonProofing::EippHelper do
  subject(:subject) { described_class }

  describe '#extract_vector_of_trust' do
    let(:vector_of_trust) { ['C1.P1.Pe'] }
    let(:sp_session) { { 'vtr' => vector_of_trust, 'acr_values' => nil } }
    it 'returns the vector_of_trust' do
      expect(subject.extract_vector_of_trust(sp_session)).to eq(vector_of_trust)
    end

    context 'when the user enters the flow without a service provider' do
      let(:sp_session) { {} }
      it 'returns nil' do
        expect(subject.extract_vector_of_trust(sp_session)).to be nil
      end
    end
  end

  describe '#is_eipp?' do
    context 'when user is going through EIPP' do
      let(:vector_of_trust) { ['C1.P1.Pe'] }
      it 'returns true' do
        expect(subject.is_eipp?(vector_of_trust)).to be true
      end
    end

    context 'when user is not going through EIPP' do
      let(:vector_of_trust) { ['C1.C2.Cb'] }
      it 'returns false' do
        expect(subject.is_eipp?(vector_of_trust)).to be false
      end
    end

    context 'when vector_of_trust is nil' do
      let(:vector_of_trust) { nil }
      it 'returns false' do
        expect(subject.is_eipp?(vector_of_trust)).to be false
      end
    end
  end
end
