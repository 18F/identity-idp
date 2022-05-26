require 'rails_helper'

describe TwoFactorAuthentication::PersonalKeySelectionPresenter do
  let(:subject) { described_class.new(configuration: configuration) }
  let(:configuration) {}

  describe '#type' do
    it 'returns personal_key' do
      expect(subject.type).to eq 'personal_key'
    end
  end
end
