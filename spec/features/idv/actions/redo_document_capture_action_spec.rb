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
      fill_out_ssn_form_with_ssn_that_fails_resolution
      click_idv_continue
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

      expect(current_path).to eq(idv_doc_auth_verify_step)
      check t('forms.ssn.show')
      expect(page).to have_content(DocAuthHelper::SSN_THAT_FAILS_RESOLUTION)
      expect(page).not_to have_css('[role="status"]')
    end

    it 'shows a troubleshooting option to allow the user to return to upload new images' do
      click_idv_continue

      expect(page).to have_link(
        t('idv.troubleshooting.options.add_new_photos'),
        href: idv_doc_auth_step_path(step: :redo_document_capture),
      )

      click_link t('idv.troubleshooting.options.add_new_photos')

      expect(current_path).to eq(idv_doc_auth_upload_step)
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

        expect(current_path).to eq(idv_doc_auth_verify_step)
        check t('forms.ssn.show')
        expect(page).to have_content(DocAuthHelper::SSN_THAT_FAILS_RESOLUTION)
        expect(page).not_to have_css('[role="status"]')
      end
    end
  end
end
