require 'rails_helper'

describe TwoFactorAuthentication::PivCacSelectionPresenter do
  let(:subject) { described_class.new(configuration) }
  let(:configuration) {}

  describe '#type' do
    it 'returns piv_cac' do
      expect(subject.type).to eq 'piv_cac'
    end
  end
end
