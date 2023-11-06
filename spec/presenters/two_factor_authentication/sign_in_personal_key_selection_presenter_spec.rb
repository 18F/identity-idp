require 'rails_helper'

RSpec.describe TwoFactorAuthentication::SignInPersonalKeySelectionPresenter do
  let(:configuration) {}
  let(:user) { build(:user) }

  subject(:presenter) { described_class.new(configuration:, user:) }

  describe '#type' do
    subject(:type) { presenter.type }

    it 'returns personal key type' do
      expect(type).to eq 'personal_key'
    end
  end

  describe '#label' do
    subject(:label) { presenter.label }

    it 'returns personal key sign in label' do
      expect(label).to eq t('two_factor_authentication.login_options.personal_key')
    end
  end

  describe '#info' do
    subject(:info) { presenter.info }

    it 'returns personal key sign in info' do
      expect(info).to eq t('two_factor_authentication.login_options.personal_key_info')
    end
  end
end
