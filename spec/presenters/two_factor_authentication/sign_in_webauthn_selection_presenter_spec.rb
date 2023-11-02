require 'rails_helper'

RSpec.describe TwoFactorAuthentication::SignInWebauthnSelectionPresenter do
  let(:user) { create(:user) }
  let(:configuration) { create(:webauthn_configuration, user: user) }

  let(:presenter) do
    described_class.new(user: user, configuration: configuration)
  end

  describe '#type' do
    it 'returns webauthn' do
      expect(presenter.type).to eq 'webauthn'
    end
  end

  describe '#label' do
    it 'raises with missing translation' do
      expect(presenter.label).to eq(
        t('two_factor_authentication.two_factor_choice_options.webauthn'),
      )
    end
  end

  describe '#info' do
    it 'raises with missing translation' do
      expect(presenter.info).to eq(
        t('two_factor_authentication.login_options.webauthn_info'),
      )
    end
  end
end
