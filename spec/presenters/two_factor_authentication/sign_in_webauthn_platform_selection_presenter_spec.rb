require 'rails_helper'

RSpec.describe TwoFactorAuthentication::SignInWebauthnPlatformSelectionPresenter do
  let(:user) { create(:user) }
  let(:configuration) { create(:webauthn_configuration, user:) }

  let(:presenter) do
    described_class.new(user:, configuration:)
  end

  describe '#type' do
    it 'returns webauthn_platform' do
      expect(presenter.type).to eq 'webauthn_platform'
    end
  end

  describe '#label' do
    it 'returns the label text' do
      expect(presenter.label).to eq(
        t('two_factor_authentication.two_factor_choice_options.webauthn_platform'),
      )
    end
  end

  describe '#info' do
    it 'returns the info text' do
      expect(presenter.info).to eq(
        t('two_factor_authentication.login_options.webauthn_platform_info'),
      )
    end
  end
end
