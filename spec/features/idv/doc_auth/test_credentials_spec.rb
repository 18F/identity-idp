require 'rails_helper'

RSpec.feature 'doc auth test credentials', :js do
  include IdvStepHelper
  include DocAuthHelper

  before do
    sign_in_and_2fa_user
    complete_doc_auth_steps_before_document_capture_step
  end

  around do |example|
    # We need to adjust the wait time to give the frontend time to poll for
    # results
    Capybara.using_wait_time(3) do
      example.run
    end
  end

  it 'allows proofing with test credentials' do
    complete_document_capture_step_with_yml('spec/fixtures/ial2_test_credential.yml')

    expect(page).to have_current_path(idv_ssn_path)

    fill_out_ssn_form_ok
    click_idv_continue

    expect(page).to have_content('Jane')
  end

  context 'displays credential errors' do
    it 'triggers an error if the test credentials have a friendly error', allow_browser_log: true do
      triggers_error_test_credentials_missing(
        'spec/fixtures/ial2_test_credential_forces_error.yml',
        I18n.t('doc_auth.errors.alerts.barcode_content_check').tr(
          ' ', ' '
        ),
      )
    end

    it 'triggers an error if the test credentials missing required address',
       allow_browser_log: true do
      triggers_error_test_credentials_missing(
        'spec/fixtures/ial2_test_credential_no_address.yml',
        I18n.t('doc_auth.errors.alerts.address_check').tr(
          ' ', ' '
        ),
      )
    end

    def triggers_error_test_credentials_missing(credential_file, alert_message)
      complete_document_capture_step_with_yml(
        credential_file,
        expected_path: idv_document_capture_url,
      )

      expect(page).to have_content(alert_message)
      expect(page).to have_current_path(idv_document_capture_url)
    end
  end

  it 'rate limits the user if invalid credentials submitted for max allowed attempts',
     allow_browser_log: true do
    allow(IdentityConfig.store).to receive(:doc_auth_check_failed_image_resubmission_enabled).
      and_return(false)
    max_attempts = IdentityConfig.store.doc_auth_max_attempts
    (max_attempts - 1).times do
      complete_document_capture_step_with_yml(
        'spec/fixtures/ial2_test_credential_no_address.yml',
        expected_path: idv_document_capture_url,
      )
      click_on t('idv.failure.button.warning')
    end

    complete_document_capture_step_with_yml(
      'spec/fixtures/ial2_test_credential_no_address.yml',
      expected_path: idv_document_capture_url,
    )

    expect(page).to have_current_path(idv_session_errors_rate_limited_path)
  end
end
