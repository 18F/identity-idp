require 'rails_helper'

shared_examples 'link sent step' do |simulate|
  feature 'doc auth link sent step' do
    include IdvStepHelper
    include DocAuthHelper
    include DocCaptureHelper

    let(:user) { user_with_2fa }

    before do
      allow(Figaro.env).to receive(:acuant_simulator).and_return(simulate)
      enable_doc_auth
      complete_doc_auth_steps_before_link_sent_step(user)
      mock_assure_id_ok
      mock_doc_captured(user.id)
    end

    it 'is on the correct page' do
      expect(page).to have_current_path(idv_doc_auth_link_sent_step)
      expect(page).to have_content(t('doc_auth.headings.text_message'))
    end

    it 'proceeds to the next page with valid info' do
      click_idv_continue

      expect(page).to have_current_path(idv_doc_auth_ssn_step)
    end

    it 'proceeds to the next page with valid info and test credentials turned on' do
      enable_test_credentials
      click_idv_continue

      expect(page).to have_current_path(idv_doc_auth_ssn_step)
    end

    it 'proceeds to the next page if the user does not have a phone' do
      complete_doc_auth_steps_before_link_sent_step(
        create(:user, :with_authentication_app, :with_piv_or_cac),
      )
      click_idv_continue

      expect(page).to have_current_path(idv_doc_auth_ssn_step)
    end

    it 'does not proceed to the next page with invalid info' do
      allow_any_instance_of(Idv::Acuant::AssureId).to receive(:post_back_image).
        and_return([false, ''])
      click_idv_continue

      expect(page).to have_current_path(idv_doc_auth_back_image_step) unless simulate
    end

    it 'does not proceed to the next page with result=2' do
      allow_any_instance_of(Idv::Acuant::AssureId).to receive(:results).
        and_return([true, assure_id_results_with_result_2])
      click_idv_continue

      expect(page).to have_current_path(idv_doc_auth_back_image_step) unless simulate
    end
  end
end

feature 'doc auth link sent' do
  it_behaves_like 'link sent step', 'false'
  it_behaves_like 'link sent step', 'true'
end
