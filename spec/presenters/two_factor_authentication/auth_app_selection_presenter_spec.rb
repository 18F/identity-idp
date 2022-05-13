require 'rails_helper'

describe TwoFactorAuthentication::AuthAppSelectionPresenter do
  let(:configuration) {}
  let(:user_without_mfa) { create(:user) }
  let(:user_with_mfa) { create(:user, :with_authentication_app) }
  let(:presenter_without_mfa) { described_class.new(configuration, user_without_mfa) }
  let(:presenter_with_mfa) { described_class.new(configuration, user_with_mfa) }

  describe '#type' do
    it 'returns auth_app' do
      expect(presenter_without_mfa.type).to eq 'auth_app'
    end
  end

  describe '#mfa_configruation' do
    it 'return an empty string when user has not configured this authenticator' do
      expect(presenter_without_mfa.mfa_configuration).to eq('')
    end
    it 'return an # added when user has configured this authenticator' do
      expect(presenter_with_mfa.mfa_configuration).to eq(
        t(
          'two_factor_authentication.two_factor_choice_options.configurations_added',
          count: 1,
        ),
      )
    end
  end
end
