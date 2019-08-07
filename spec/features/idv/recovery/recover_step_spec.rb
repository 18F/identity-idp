require 'rails_helper'

shared_examples 'recover step' do |simulate|
  feature 'recover step' do
    include IdvStepHelper
    include DocAuthHelper
    include RecoveryHelper

    token = nil
    let(:user) { create(:user) }
    let(:profile) { build(:profile, :active, :verified, user: user, pii: { ssn: '1234' }) }

    before do
      allow(Figaro.env).to receive(:acuant_simulator).and_return(simulate)
      enable_doc_auth
      sign_in_before_2fa(user)
      token = complete_recovery_steps_before_recover_step(user)
      mock_assure_id_ok
    end

    it 'is on the correct page' do
      expect(page).to have_current_path(idv_recovery_recover_step(token))
      expect(page).to have_content(t('recover.reverify.email_confirmed'))
    end

    it 'proceeds to the next page' do
      click_idv_continue

      expect(page).to have_current_path(idv_recovery_overview_step)
    end
  end
end

feature 'recovery step' do
  it_behaves_like 'recover step', 'false'
  it_behaves_like 'recover step', 'true'
end
