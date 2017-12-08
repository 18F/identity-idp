require 'rails_helper'

feature 'Interrupted IdV session' do
  include IdvHelper

  describe 'Closing the browser while on the first form', js: true, idv_job: true do
    before do
      sign_in_and_2fa_user
      visit verify_session_path
    end

    context 'when the alert is dismissed' do
      it 'does not display an alert when submitting the form' do
        # dismiss the alert that appears when the user closes the browser window
        # dismiss means the user clicked on "Stay on Page"
        page.driver.browser.dismiss_confirm do
          page.driver.close_window(page.driver.current_window_handle)
        end

        fill_out_idv_form_ok
        click_button t('forms.buttons.continue')

        expect(page).to have_content(t('idv.messages.select_verification_form.phone_message'))
      end
    end
  end
end
