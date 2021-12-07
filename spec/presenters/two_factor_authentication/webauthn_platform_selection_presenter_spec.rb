require 'rails_helper'

describe TwoFactorAuthentication::WebauthnPlatformSelectionPresenter do
  let(:subject) { described_class.new(configuration) }
  let(:configuration) {}

  describe '#type' do
    it 'returns webauthn_platform' do
      expect(subject.type).to eq 'webauthn_platform'
    end
  end

  describe '#html_class' do
    it 'returns display-none' do
      expect(subject.html_class).to eq 'display-none'
    end
  end
end
