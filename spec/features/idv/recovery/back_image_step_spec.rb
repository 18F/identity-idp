require 'rails_helper'

shared_examples 'recovery back image step' do |simulate|
  feature 'recovery back image step' do
    include IdvStepHelper
    include DocAuthHelper
    include RecoveryHelper

    let(:user) { create(:user) }
    let(:profile) { build(:profile, :active, :verified, user: user, pii: { ssn: '1234' }) }
    let(:user_no_phone) { create(:user, :with_authentication_app, :with_piv_or_cac) }
    let(:profile) { build(:profile, :active, :verified, user: user_no_phone, pii: { ssn: '1234' }) }

    before do |example|
      select_user = example.metadata[:no_phone] ? user_no_phone : user
      allow(Figaro.env).to receive(:acuant_simulator).and_return(simulate)
      sign_in_before_2fa(user)
      enable_doc_auth
      complete_recovery_steps_before_back_image_step(select_user)
      mock_assure_id_ok
    end

    it 'is on the correct page' do
      expect(page).to have_current_path(idv_recovery_back_image_step)
      expect(page).to have_content(t('doc_auth.headings.upload_back'))
    end

    it 'proceeds to the next page with valid info' do
      attach_image
      click_idv_continue

      expect(page).to have_current_path(idv_recovery_ssn_step)
    end

    it 'proceeds to the next page if the user does not have a phone', :no_phone do
      attach_image
      click_idv_continue

      expect(page).to have_current_path(idv_recovery_ssn_step)
    end

    it 'does not proceed to the next page with invalid info' do
      allow_any_instance_of(Idv::Acuant::AssureId).to receive(:post_back_image).
        and_return([false, ''])
      attach_image
      click_idv_continue

      expect(page).to have_current_path(idv_recovery_back_image_step) unless simulate
    end

    it 'does not proceed to the next page with result=2' do
      allow_any_instance_of(Idv::Acuant::AssureId).to receive(:results).
        and_return([true, assure_id_results_with_result_2])
      attach_image
      click_idv_continue

      expect(page).to have_current_path(idv_doc_auth_front_image_step) unless simulate
      expect(page).to have_content(I18n.t('errors.doc_auth.general_error')) unless simulate
      expect(page).to have_content(I18n.t('errors.doc_auth.general_info')) unless simulate
    end
  end
end

feature 'recovery back image' do
  it_behaves_like 'recovery back image step', 'false'
  it_behaves_like 'recovery back image step', 'true'
end
