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
        text: t(
          'doc_auth.headings.capture_scan_warning_html',
          link: warning_link_text,
        ).tr(' ', ' '),
      )
      click_link warning_link_text

      expect(current_path).to eq(idv_hybrid_handoff_path)
      complete_upload_step
      DocAuth::Mock::DocAuthMockClient.reset!
      attach_and_submit_images

      expect(current_path).to eq(idv_verify_info_path)
      check t('forms.ssn.show')
      expect(page).to have_content(DocAuthHelper::SSN_THAT_FAILS_RESOLUTION)
      expect(page).to have_css('[role="status"]')  # We verified your ID
    end

    it 'shows a troubleshooting option to allow the user to cancel and return to SP' do
      click_idv_continue

      expect(page).to have_link(
        t('links.cancel'),
        href: idv_cancel_path,
      )

      click_link t('links.cancel')

      expect(current_path).to eq(idv_cancel_path)
    end

    context 'on mobile', driver: :headless_chrome_mobile do
      it 'shows a warning message to allow the user to return to upload new images' do
        warning_link_text = t('doc_auth.headings.capture_scan_warning_link')

        expect(page).to have_css(
          '[role="status"]',
          text: t(
            'doc_auth.headings.capture_scan_warning_html',
            link: warning_link_text,
          ).tr(' ', ' '),
        )
        click_link warning_link_text

        expect(current_path).to eq(idv_document_capture_path)
        DocAuth::Mock::DocAuthMockClient.reset!
        attach_and_submit_images

        expect(current_path).to eq(idv_verify_info_path)
        check t('forms.ssn.show')
        expect(page).to have_content(DocAuthHelper::SSN_THAT_FAILS_RESOLUTION)
        expect(page).to have_css('[role="status"]') # We verified your ID
      end
    end
  end
end
