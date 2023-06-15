require 'rails_helper'

RSpec.feature 'doc auth redo document capture', js: true do
  include IdvStepHelper
  include DocAuthHelper

  let(:fake_analytics) { FakeAnalytics.new }

  before do
    allow_any_instance_of(ApplicationController).to receive(:analytics).and_return(fake_analytics)
  end

  context 'when barcode scan returns a warning', allow_browser_log: true do
    let(:use_bad_ssn) { false }

    before do
      sign_in_and_2fa_user
      complete_doc_auth_steps_before_document_capture_step
      mock_doc_auth_attention_with_barcode
      attach_and_submit_images
      click_idv_continue

      if use_bad_ssn
        fill_out_ssn_form_with_ssn_that_fails_resolution
      else
        fill_out_ssn_form_ok
      end

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
      expect(fake_analytics).to have_logged_event(
        'IdV: doc auth upload visited',
        hash_including(redo_document_capture: true),
      )
      complete_hybrid_handoff_step
      expect(fake_analytics).to have_logged_event(
        'IdV: doc auth document_capture visited',
        hash_including(redo_document_capture: true),
      )
      DocAuth::Mock::DocAuthMockClient.reset!
      attach_and_submit_images

      expect(current_path).to eq(idv_verify_info_path)
      check t('forms.ssn.show')
      expect(page).to have_content(DocAuthHelper::GOOD_SSN)
      expect(page).to have_css('[role="status"]')  # We verified your ID
    end

    xit 'document capture cannot be reached after submitting verify info step' do
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
      complete_hybrid_handoff_step

      visit idv_verify_info_url

      click_idv_continue

      expect(page).to have_current_path(idv_phone_path)

      fill_out_phone_form_fail

      click_idv_send_security_code

      expect(page).to have_content(t('idv.failure.phone.warning.heading'))

      visit idv_url
      expect(current_path).to eq(idv_phone_path)

      visit idv_hybrid_handoff_url
      expect(current_path).to eq(idv_phone_path)

      visit idv_document_capture_url
      expect(current_path).to eq(idv_phone_path)

      visit idv_ssn_url
      expect(current_path).to eq(idv_phone_path)

      visit idv_verify_info_url
      expect(current_path).to eq(idv_phone_path)
    end

    context 'with a bad SSN' do
      let(:use_bad_ssn) { true }

      it 'shows a troubleshooting option to allow the user to cancel and return to SP' do
        click_idv_continue

        expect(page).to have_link(
          t('links.cancel'),
          href: idv_cancel_path,
        )

        click_link t('links.cancel')

        expect(current_path).to eq(idv_cancel_path)
      end
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
        expect(fake_analytics).to have_logged_event(
          'IdV: doc auth document_capture visited',
          hash_including(redo_document_capture: true),
        )
        DocAuth::Mock::DocAuthMockClient.reset!
        attach_and_submit_images

        expect(current_path).to eq(idv_verify_info_path)
        check t('forms.ssn.show')
        expect(page).to have_content(DocAuthHelper::GOOD_SSN)
        expect(page).to have_css('[role="status"]') # We verified your ID
      end
    end
  end
end
