require 'rails_helper'

RSpec.feature 'doc auth redo document capture', js: true do
  include IdvStepHelper
  include DocAuthHelper
  include DocCaptureHelper

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
          link_html: warning_link_text,
        ).tr(' ', ' '),
      )
      click_link warning_link_text

      expect(current_path).to eq(idv_hybrid_handoff_path)
      expect(fake_analytics).to have_logged_event(
        'IdV: doc auth hybrid handoff visited',
        hash_including(redo_document_capture: true),
      )
      complete_hybrid_handoff_step
      expect(fake_analytics).to have_logged_event(
        'IdV: doc auth document_capture visited',
        hash_including(redo_document_capture: true),
      )
      DocAuth::Mock::DocAuthMockClient.reset!
      attach_and_submit_images

      expect(current_path).to eq(idv_ssn_path)
      expect(page).to have_css('[role="status"]') # We verified your ID
      complete_ssn_step

      expect(current_path).to eq(idv_verify_info_path)
      check t('forms.ssn.show')
      expect(page).to have_content(DocAuthHelper::GOOD_SSN)
    end

    context 'with a bad SSN' do
      let(:use_bad_ssn) { true }

      it 'shows a troubleshooting option to allow the user to cancel and return to SP' do
        complete_verify_step
        expect(page).to have_link(
          t('links.cancel'),
          href: idv_cancel_path(step: :invalid_session),
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
            link_html: warning_link_text,
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

        expect(current_path).to eq(idv_ssn_path)
        expect(page).to have_css('[role="status"]') # We verified your ID
        complete_ssn_step

        expect(current_path).to eq(idv_verify_info_path)
        check t('forms.ssn.show')
        expect(page).to have_content(DocAuthHelper::GOOD_SSN)
      end
    end
  end

  shared_examples_for 'image re-upload allowed' do
    it 'allows user to submit the same image again' do
      expect(fake_analytics).to have_logged_event(
        'IdV: doc auth document_capture visited',
        hash_including(redo_document_capture: nil),
      )
      expect(fake_analytics).to have_logged_event(
        'IdV: doc auth image upload form submitted',
        hash_including(remaining_attempts: 3),
      )
      DocAuth::Mock::DocAuthMockClient.reset!
      attach_and_submit_images
      expect(fake_analytics).to have_logged_event(
        'IdV: doc auth image upload form submitted',
        hash_including(remaining_attempts: 2),
      )
      expect(current_path).to eq(idv_ssn_path)
      check t('forms.ssn.show')
    end
  end

  shared_examples_for 'image re-upload not allowed' do
    it 'stops user submitting the same image again' do
      expect(fake_analytics).to have_logged_event(
        'IdV: doc auth document_capture visited',
        hash_including(redo_document_capture: nil),
      )
      expect(fake_analytics).to have_logged_event(
        'IdV: doc auth image upload form submitted',
        hash_including(remaining_attempts: 3, attempts: 1),
      )
      DocAuth::Mock::DocAuthMockClient.reset!
      attach_images
      # Error message without submit
      expect(page).to have_css(
        '.usa-error-message[role="alert"]',
        text: t('doc_auth.errors.doc.resubmit_failed_image'),
      )
    end
  end

  shared_examples_for 'inline error for 4xx status shown' do |status|
    it "shows inline error for status #{status}" do
      error = case status
              when 438
                t('doc_auth.errors.http.image_load.failed_short')
              when 439
                t('doc_auth.errors.http.pixel_depth.failed_short')
              when 440
                t('doc_auth.errors.http.image_size.failed_short')
              end
      expect(page).to have_css(
        '.usa-error-message[role="alert"]',
        text: error,
      )
    end
  end
  context 'error due to data issue with 2xx status code', allow_browser_log: true do
    before do
      sign_in_and_2fa_user
      complete_doc_auth_steps_before_document_capture_step
      mock_doc_auth_acuant_error_unknown
      attach_and_submit_images
      click_try_again
    end
    it_behaves_like 'image re-upload not allowed'
  end

  context 'error due to data issue with 4xx status code with trueid', allow_browser_log: true do
    before do
      sign_in_and_2fa_user
      complete_doc_auth_steps_before_document_capture_step
      mock_doc_auth_trueid_http_non2xx_status(438)
      attach_and_submit_images
      click_try_again
    end

    it_behaves_like 'image re-upload allowed'
  end

  context 'error due to http status error but non 4xx status code with trueid',
          allow_browser_log: true do
    before do
      sign_in_and_2fa_user
      complete_doc_auth_steps_before_document_capture_step
      mock_doc_auth_trueid_http_non2xx_status(500)
      attach_and_submit_images
      click_try_again
    end
    it_behaves_like 'image re-upload allowed'
  end

  context 'error due to data issue with 4xx status code with assureid', allow_browser_log: true do
    before do
      sign_in_and_2fa_user
      complete_doc_auth_steps_before_document_capture_step
      mock_doc_auth_acuant_http_4xx_status(440)
      attach_and_submit_images
      click_try_again
    end
    it_behaves_like 'inline error for 4xx status shown', 440
    it_behaves_like 'image re-upload not allowed'
  end

  context 'error due to data issue with 5xx status code with assureid', allow_browser_log: true do
    before do
      sign_in_and_2fa_user
      complete_doc_auth_steps_before_document_capture_step
      mock_doc_auth_acuant_http_5xx_status
      attach_and_submit_images
      click_try_again
    end

    it_behaves_like 'image re-upload allowed'
  end

  context 'unknown error for acuant', allow_browser_log: true do
    before do
      sign_in_and_2fa_user
      complete_doc_auth_steps_before_document_capture_step
      mock_doc_auth_acuant_error_unknown
      attach_and_submit_images
      click_try_again
    end

    it_behaves_like 'image re-upload not allowed'
  end

  context 'when selfie is enabled' do
    context 'error due to data issue with 2xx status code', allow_browser_log: true do
      before do
        allow(IdentityConfig.store).to receive(:doc_auth_selfie_capture_enabled).and_return(true)
        allow_any_instance_of(FederatedProtocols::Oidc).
          to receive(:biometric_comparison_required?).and_return(true)
        start_idv_from_sp
        sign_in_and_2fa_user
        complete_doc_auth_steps_before_document_capture_step
        mock_doc_auth_acuant_error_unknown
        attach_images
        attach_selfie
        submit_images
        click_try_again
        sleep(10)
      end
      it_behaves_like 'image re-upload not allowed'
      it 'shows current existing header' do
        expect_doc_capture_page_header(t('doc_auth.headings.review_issues'))
      end
    end
  end
end
