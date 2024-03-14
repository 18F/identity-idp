require 'rails_helper'

RSpec.describe TwoFactorAuthentication::SetUpAuthAppSelectionPresenter do
  let(:user) { create(:user) }
  let(:presenter) { described_class.new(user:) }

  describe '#type' do
    it 'returns auth_app' do
      expect(presenter.type).to eq(:auth_app)
    end
  end

  describe '#mfa_configuration_description' do
    subject(:mfa_configuration_description) { presenter.mfa_configuration_description }

    context 'when user has not configured this authenticator' do
      let(:user) { create(:user) }

      it 'return an empty string' do
        expect(mfa_configuration_description).to eq('')
      end
    end

    context 'when user has configured this authenticator' do
      let(:user) { create(:user, :with_authentication_app) }

      it 'returns text with number of added authenticators' do
        expect(mfa_configuration_description).to eq(
          t(
            'two_factor_authentication.two_factor_choice_options.configurations_added',
            count: 1,
          ),
        )
      end
    end
  end

  describe '#phishing_resistant?' do
    subject(:phishing_resistant) { presenter.phishing_resistant? }

    it { expect(phishing_resistant).to eq(false) }
  end
end
