require 'rails_helper'

feature 'doc auth welcome step' do
  include DocAuthHelper

  context 'button is disabled when JS is enabled', :js do
    before do
      enable_doc_auth
      sign_in_and_2fa_user(user_with_2fa)
      visit idv_doc_auth_welcome_step unless current_path == idv_doc_auth_welcome_step
    end

    it 'does not allow the user to continue without checking the checkbox' do
      expect(page).to have_button('Continue', disabled: true)
    end

    it 'allows the user to continue after checking the checkbox' do
      find('span[class="indicator"]').set(true)
      expect(page).to have_button('Continue', disabled: false)
      click_on t('doc_auth.buttons.continue')

      expect(page).to have_current_path(idv_doc_auth_upload_step)
    end
  end

  context 'button is clickable when JS is disabled' do
    before do
      enable_doc_auth
      sign_in_and_2fa_user(user_with_2fa)
      visit idv_doc_auth_welcome_step unless current_path == idv_doc_auth_welcome_step
    end

    it 'renders error when user continues without checking the checkbox' do
      click_on t('doc_auth.buttons.continue')

      expect(page).to have_current_path(idv_doc_auth_welcome_step)
      expect(page).to have_content(t('errors.doc_auth.consent_form'))
    end

    it 'allows the user to continue after checking the checkbox' do
      find('input[name="ial2_consent_given"]').set(true)
      click_on t('doc_auth.buttons.continue')

      expect(page).to have_current_path(idv_doc_auth_upload_step)
    end
  end
end
