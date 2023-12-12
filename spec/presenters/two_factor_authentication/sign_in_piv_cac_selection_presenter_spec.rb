require 'rails_helper'

RSpec.describe TwoFactorAuthentication::SignInPivCacSelectionPresenter do
  let(:user) { create(:user) }
  let(:configuration) { create(:piv_cac_configuration, user: user) }

  let(:presenter) do
    described_class.new(user: user, configuration: configuration)
  end

  describe '#type' do
    it 'returns piv_cac' do
      expect(presenter.type).to eq :piv_cac
    end
  end

  describe '#label' do
    it 'returns the label text' do
      expect(presenter.label).to eq(
        t('two_factor_authentication.two_factor_choice_options.piv_cac'),
      )
    end
  end

  describe '#info' do
    it 'returns the info text' do
      expect(presenter.info).to eq(
        t('two_factor_authentication.login_options.piv_cac_info'),
      )
    end
  end
end
