require 'rails_helper'

RSpec.describe TwoFactorAuthentication::PersonalKeySelectionPresenter do
  let(:subject) { described_class.new(configuration: configuration, user: user) }
  let(:configuration) {}
  let(:user) { build(:user) }
  describe '#type' do
    it 'returns personal_key' do
      expect(subject.type).to eq 'personal_key'
    end
  end
end
