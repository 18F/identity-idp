require 'rails_helper'

describe TwoFactorAuthentication::PivCacSelectionPresenter do
  let(:user_without_mfa) { create(:user) }
  let(:user_with_mfa) { create(:user, :with_piv_or_cac) }
  let(:configuration) {}
  let(:presenter_without_mfa) {
    described_class.new(configuration: configuration, user: user_without_mfa)
  }
  let(:presenter_with_mfa) {
    described_class.new(configuration: configuration, user: user_with_mfa)
  }

  describe '#type' do
    it 'returns piv_cac' do
      expect(presenter_without_mfa.type).to eq 'piv_cac'
    end
  end

  describe '#mfa_configruation' do
    it 'returns an empty string when user has not configured this authenticator' do
      expect(presenter_without_mfa.mfa_configuration_description).to eq('')
    end
    it 'returns an # added when user has configured this authenticator' do
      expect(presenter_with_mfa.mfa_configuration_description).to eq(
        t(
          'two_factor_authentication.two_factor_choice_options.configurations_added',
          count: 1,
        ),
      )
    end
  end
end
