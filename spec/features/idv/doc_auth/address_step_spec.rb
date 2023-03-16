require 'rails_helper'

feature 'doc auth verify step', :js do
  include IdvStepHelper
  include DocAuthHelper

  context 'with mainland address' do
    before do
      sign_in_and_2fa_user
      complete_doc_auth_steps_before_address_step
    end

    it 'allows the user to enter in a new address' do
      expect_step_indicator_current_step(t('step_indicator.flows.idv.verify_info'))
      expect(page).not_to have_content(t('doc_auth.info.address_guidance_puerto_rico_html'))
      expect(page).not_to have_content(t('forms.example'))
      fill_out_address_form_ok

      click_button t('forms.buttons.submit.update')
      expect(page).to have_current_path(idv_verify_info_path)
    end

    it 'does not allow the user to enter bad address info' do
      fill_out_address_form_fail

      click_button t('forms.buttons.submit.update')
      expect(page).to have_current_path(idv_address_path)
    end

    it 'allows the user to click back to return to the verify step' do
      click_doc_auth_back_link

      expect(page).to have_current_path(idv_verify_info_path)
    end

    it 'sends the user to start doc auth if there is no pii from the document in session' do
      visit sign_out_url
      sign_in_and_2fa_user
      visit idv_address_path

      expect(page).to have_current_path(idv_doc_auth_welcome_step)
    end
  end

  context 'with Puerto Rico address' do
    before do
      sign_in_and_2fa_user
      complete_doc_auth_steps_before_document_capture_step
      complete_document_capture_step_with_yml('spec/fixtures/puerto_rico_resident.yml')
      complete_ssn_step
    end

    it 'shows address guidance and hint text' do
      expect(page).to have_current_path(idv_address_url)
      expect(page.body).to include(t('doc_auth.info.address_guidance_puerto_rico_html'))
      expect(page).to have_content(t('forms.example'))
      fill_in 'idv_form_address1', with: '123 Calle Carlos'
      fill_in 'idv_form_address2', with: 'URB Las Gladiolas'
      click_button t('forms.buttons.submit.update')
      expect(page).to have_current_path(idv_verify_info_path)
    end
  end
end
