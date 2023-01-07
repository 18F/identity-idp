require 'rails_helper'

feature 'doc auth verify_info step', :js do
  include IdvStepHelper
  include DocAuthHelper
  include DocCaptureHelper

  context 'with verify_info_controller enabled' do
    before do
      allow(IdentityConfig.store).to receive(:doc_auth_verify_info_controller_enabled).
        and_return(true)
      sign_in_and_2fa_user
      complete_doc_auth_steps_before_verify_step
    end

    it 'displays the expected content' do
      expect(page).to have_current_path(idv_verify_info_path)
      expect(page).to have_content(t('headings.verify'))
      expect(page).to have_content(t('step_indicator.flows.idv.verify_info'))

      # SSN is masked until revealed
      expect(page).to have_text('9**-**-***4')
      expect(page).not_to have_text(DocAuthHelper::GOOD_SSN)
      check t('forms.ssn.show')
      expect(page).not_to have_text('9**-**-***4')
      expect(page).to have_text(DocAuthHelper::GOOD_SSN)
    end

    it 'allows the user to enter in a new address' do
      click_button t('idv.buttons.change_address_label')
      fill_out_address_form_ok
      click_button t('forms.buttons.submit.update')

      expect(page).to have_current_path(idv_verify_info_path)
    end

    it 'displays the correct updated address information' do
      click_button t('idv.buttons.change_address_label')
      fill_in 'idv_form_zipcode', with: '12345'
      click_button t('forms.buttons.submit.update')

      expect(page).to have_content('12345')
    end

    it 'allows the user to enter in a new ssn' do
      click_button t('idv.buttons.change_ssn_label')
      fill_out_ssn_form_ok
      click_button t('forms.buttons.submit.update')

      expect(page).to have_current_path(idv_verify_info_path)
    end

    it 'displays the correct updated address information' do
      click_button t('idv.buttons.change_ssn_label')
      fill_in t('idv.form.ssn_label_html'), with: '900456789'
      click_button t('forms.buttons.submit.update')

      expect(page).to have_text('9**-**-***9')
      check t('forms.ssn.show')
      expect(page).to have_text('900-45-6789')
    end
  end
end
