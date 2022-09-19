require 'rails_helper'

feature 'inherited proofing agreement' do
  include IdvHelper
  include DocAuthHelper

  def expect_ip_verify_info_step
    expect(page).to have_current_path(idv_ip_verify_info_step)
  end

  def expect_inherited_proofing_first_step
    expect(page).to have_current_path(idv_inherited_proofing_agreement_step)
  end

  context 'when JS is enabled', :js do
    before do
      sign_in_and_2fa_user
      complete_inherited_proofing_steps_before_agreement_step
    end

    it 'shows an inline error if the user clicks continue without giving consent' do
      click_continue
      expect_inherited_proofing_first_step
      expect(page).to have_content(t('forms.validation.required_checkbox'))
    end

    it 'allows the user to continue after checking the checkbox' do
      check t('inherited_proofing.instructions.consent', app_name: APP_NAME)
      click_continue

      expect_ip_verify_info_step
    end
  end

  context 'when JS is disabled' do
    before do
      sign_in_and_2fa_user
      complete_inherited_proofing_steps_before_agreement_step
    end

    it 'shows the notice if the user clicks continue without giving consent' do
      click_continue

      expect_inherited_proofing_first_step
      expect(page).to have_content(t('errors.doc_auth.consent_form'))
    end

    it 'allows the user to continue after checking the checkbox' do
      check t('inherited_proofing.instructions.consent', app_name: APP_NAME)
      click_continue

      expect_ip_verify_info_step
    end
  end
end
