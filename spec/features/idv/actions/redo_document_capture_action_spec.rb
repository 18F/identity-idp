require 'rails_helper'

feature 'doc auth redo document capture action', js: true do
  include IdvStepHelper
  include DocAuthHelper

  context 'when barcode scan returns a warning', allow_browser_log: true do
    before do
      sign_in_and_2fa_user
      complete_doc_auth_steps_before_document_capture_step
      mock_doc_auth_attention_with_barcode
      attach_and_submit_images
      click_idv_continue
      complete_ssn_step
    end

    it 'shows a warning message to allow the user to return to upload new images' do
      warning_link_text = t('doc_auth.headings.capture_scan_warning_link')

      expect(page).to have_css(
        '[role="status"]',
        text: t('doc_auth.headings.capture_scan_warning_html', link: warning_link_text),
      )
      click_link warning_link_text

      expect(current_path).to eq(idv_doc_auth_upload_step)
      complete_upload_step
      DocAuth::Mock::DocAuthMockClient.reset!
      attach_and_submit_images
      complete_ssn_step

      expect(page).not_to have_css('[role="status"]')
    end

    context 'on mobile', driver: :headless_chrome_mobile do
      it 'shows a warning message to allow the user to return to upload new images' do
        warning_link_text = t('doc_auth.headings.capture_scan_warning_link')

        expect(page).to have_css(
          '[role="status"]',
          text: t('doc_auth.headings.capture_scan_warning_html', link: warning_link_text),
        )
        click_link warning_link_text

        expect(current_path).to eq(idv_doc_auth_document_capture_step)
        DocAuth::Mock::DocAuthMockClient.reset!
        attach_and_submit_images
        complete_ssn_step

        expect(page).not_to have_css('[role="status"]')
      end
    end
  end
end
