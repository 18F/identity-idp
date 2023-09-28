require 'rails_helper'

RSpec.describe TwoFactorAuthentication::SignInAuthAppSelectionPresenter do
  let(:user) { create(:user) }
  let(:configuration) { create(:auth_app_configuration, user: user) }

  let(:presenter) do
    described_class.new(user: user, configuration: configuration)
  end

  describe '#type' do
    it 'returns auth_app' do
      expect(presenter.type).to eq 'auth_app'
    end
  end

  describe '#label' do
    it 'raises with missing translation' do
      expect(presenter.label).to eq(t('two_factor_authentication.login_options.auth_app'))
    end
  end

  describe '#info' do
    it 'raises with missing translation' do
      expect(presenter.info).to eq(t('two_factor_authentication.login_options.auth_app_info'))
    end
  end
end
