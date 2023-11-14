require 'rails_helper'

RSpec.describe TwoFactorAuthentication::SetUpPivCacSelectionPresenter do
  let(:user_without_mfa) { create(:user) }
  let(:user_with_mfa) { create(:user, :with_piv_or_cac) }
  let(:presenter_without_mfa) do
    described_class.new(user: user_without_mfa)
  end
  let(:presenter_with_mfa) do
    described_class.new(user: user_with_mfa)
  end

  describe '#type' do
    it 'returns piv_cac' do
      expect(presenter_without_mfa.type).to eq 'piv_cac'
    end
  end

  describe '#mfa_configruation' do
    it 'returns an empty string when user has not configured piv/cac' do
      expect(presenter_without_mfa.mfa_configuration_description).to eq('')
    end
    it 'returns the translated string for added when user has configured piv/cac' do
      expect(presenter_with_mfa.mfa_configuration_description).to eq(
        t(
          'two_factor_authentication.two_factor_choice_options.no_count_configuration_added',
        ),
      )
    end
  end
end
