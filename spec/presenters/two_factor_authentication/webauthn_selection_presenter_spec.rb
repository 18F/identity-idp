require 'rails_helper'

describe TwoFactorAuthentication::WebauthnSelectionPresenter do
  let(:subject) { described_class.new(configuration) }
  let(:configuration) {}

  describe '#type' do
    it 'returns webauthn' do
      expect(subject.type).to eq 'webauthn'
    end
  end

  describe '#html_class' do
    it 'returns hide' do
      expect(subject.html_class).to eq 'hide'
    end
  end
end
