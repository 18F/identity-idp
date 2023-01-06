require 'rails_helper'

feature 'doc auth verify_info step', :js do
  include IdvStepHelper
  include DocAuthHelper
  include DocCaptureHelper

  before do
    sign_in_and_2fa_user
    complete_doc_auth_steps_before_verify_step
  end

  context 'with verify_info_controller enabled' do
    before do
      allow(IdentityConfig.store).to receive(:doc_auth_verify_info_controller_enabled).
        and_return(true)
    end

    it 'shows the StepIndicator at the verify info step' do
      expect(page).to have_content(t('step_indicator.flows.idv.verify_info'))
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
  end
end
