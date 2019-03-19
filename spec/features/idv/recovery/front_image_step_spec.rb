require 'rails_helper'

shared_examples 'recovery front image step' do |simulate|
  feature 'recovery front image step' do
    include IdvStepHelper
    include DocAuthHelper
    include RecoveryHelper

    let(:user) { create(:user) }
    let(:profile) { build(:profile, :active, :verified, user: user, pii: { ssn: '1234' }) }

    before do
      allow(Figaro.env).to receive(:acuant_simulator).and_return(simulate)
      sign_in_before_2fa(user)
      enable_doc_auth
      complete_recovery_steps_before_front_image_step(user)
      mock_assure_id_ok
    end

    it 'is on the correct page' do
      expect(page).to have_current_path(idv_recovery_front_image_step)
      expect(page).to have_content(t('doc_auth.headings.upload_front'))
    end

    it 'proceeds to the next page with valid info' do
      attach_image
      click_idv_continue

      expect(page).to have_current_path(idv_recovery_back_image_step)
    end

    it 'does not proceed to the next page with invalid info' do
      mock_assure_id_fail
      attach_image
      click_idv_continue

      expect(page).to have_current_path(idv_recovery_front_image_step)
    end
  end
end

feature 'recovery front image' do
  it_behaves_like 'recovery front image step', 'false'
  it_behaves_like 'recovery front image step', 'true'
end
