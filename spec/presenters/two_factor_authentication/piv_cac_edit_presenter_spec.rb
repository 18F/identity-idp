require 'rails_helper'

RSpec.describe TwoFactorAuthentication::PivCacEditPresenter do
  subject(:presenter) { described_class.new }

  describe '#heading' do
    it 'returns heading text' do
      expect(presenter.heading).to eq(t('two_factor_authentication.piv_cac.edit_heading'))
    end
  end

  describe '#nickname_field_label' do
    it 'returns nickname field label' do
      expect(presenter.nickname_field_label).to eq(t('two_factor_authentication.piv_cac.nickname'))
    end
  end

  describe '#rename_button_label' do
    it 'returns rename button label' do
      expect(presenter.rename_button_label)
        .to eq(t('two_factor_authentication.piv_cac.change_nickname'))
    end
  end

  describe '#delete_button_label' do
    it 'returns delete button label' do
      expect(presenter.delete_button_label).to eq(t('two_factor_authentication.piv_cac.delete'))
    end
  end

  describe '#confirm_delete_heading' do
    it 'returns the confirm delete heading' do
      expect(presenter.confirm_delete_heading)
        .to eq(t('two_factor_authentication.piv_cac.confirm_delete'))
    end
  end

  describe '#caution_delete' do
    it 'returns the caution copy' do
      expect(presenter.caution_delete)
        .to eq(t('two_factor_authentication.piv_cac.caution_delete'))
    end
  end

  describe '#rename_success_alert_text' do
    it 'returns rename success alert text' do
      expect(presenter.rename_success_alert_text)
        .to eq(t('two_factor_authentication.piv_cac.renamed'))
    end
  end

  describe '#delete_success_alert_text' do
    it 'returns delete success alert text' do
      expect(presenter.delete_success_alert_text)
        .to eq(t('two_factor_authentication.piv_cac.deleted'))
    end
  end
end
