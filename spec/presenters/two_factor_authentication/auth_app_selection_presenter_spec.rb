require 'rails_helper'

describe TwoFactorAuthentication::AuthAppSelectionPresenter do
  let(:subject) { described_class.new(configuration) }
  let(:configuration) {}

  describe '#type' do
    it 'returns auth_app' do
      expect(subject.type).to eq 'auth_app'
    end
  end
end
