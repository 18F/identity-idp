require 'rails_helper'

describe TwoFactorAuthentication::WebauthnSelectionPresenter do
  let(:user_without_mfa) { create(:user) }
  let(:user_with_mfa) { create(:user) }
  let(:configuration) {}
  let(:presenter_without_mfa) do
    described_class.new(configuration: configuration, user: user_without_mfa)
  end
  let(:presenter_with_mfa) do
    described_class.new(configuration: configuration, user: user_with_mfa)
  end

  describe '#type' do
    it 'returns webauthn' do
      expect(presenter_without_mfa.type).to eq 'webauthn'
    end
  end

  describe '#html_class' do
    it 'returns display-none' do
      expect(presenter_without_mfa.html_class).to eq 'display-none'
    end
  end

  describe '#mfa_configruation' do
    it 'returns an empty string when user has not configured this authenticator' do
      expect(presenter_without_mfa.mfa_configuration_description).to eq('')
    end

    it 'returns an # added when user has configured this authenticator' do
      create(:webauthn_configuration, platform_authenticator: false, user: user_with_mfa)
      expect(presenter_with_mfa.mfa_configuration_description).to eq(
        t(
          'two_factor_authentication.two_factor_choice_options.configurations_added',
          count: 1,
        ),
      )
    end
  end
end
