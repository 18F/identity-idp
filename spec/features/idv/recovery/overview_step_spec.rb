require 'rails_helper'

feature 'recovery overview step' do
  include IdvStepHelper
  include DocAuthHelper
  include RecoveryHelper

  let(:user) { create(:user, :with_phone) }
  let(:good_ssn) { '666-66-1234' }
  let(:profile) { build(:profile, :active, :verified, user: user, pii: { ssn: good_ssn }) }

  context 'button is disabled when JS is enabled', :js do
    before do
      sign_in_before_2fa(user)
      enable_doc_auth
      mock_assure_id_ok
      complete_recovery_steps_before_overview_step(user)
    end

    it 'does not allow the user to continue without checking the checkbox' do
      expect(page).to have_button('Continue', disabled: true)
    end

    it 'allows the user to continue after checking the checkbox' do
      find('span[class="indicator"]').set(true)
      expect(page).to have_button('Continue', disabled: false)
      click_on t('recover.buttons.continue')

      expect(page).to have_current_path(idv_recovery_upload_step)
    end
  end

  context 'button is clickable when JS is disabled' do
    before do
      sign_in_before_2fa(user)
      enable_doc_auth
      mock_assure_id_ok
      complete_recovery_steps_before_overview_step(user)
    end

    it 'renders error when user continues without checking the checkbox' do
      click_on t('doc_auth.buttons.continue')

      expect(page).to have_current_path(idv_recovery_overview_step)
      expect(page).to have_content(t('errors.doc_auth.consent_form'))
    end

    it 'allows the user to continue after checking the checkbox' do
      find('input[name="ial2_consent_given"]').set(true)
      click_on t('recover.buttons.continue')

      expect(page).to have_current_path(idv_recovery_upload_step)
    end
  end
end
