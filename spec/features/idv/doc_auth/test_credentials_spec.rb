require 'rails_helper'

RSpec.feature 'doc auth test credentials', :js do
  include IdvStepHelper
  include DocAuthHelper

  before do
    sign_in_and_2fa_user
  end

  around do |example|
    # We need to adjust the wait time to give the frontend time to poll for
    # results
    Capybara.using_wait_time(3) do
      example.run
    end
  end

  it 'allows proofing with test credentials' do
    complete_doc_auth_steps_before_document_capture_step
    complete_document_capture_step_with_yml('spec/fixtures/ial2_test_credential.yml')

    expect(page).to have_current_path(idv_ssn_path)

    fill_out_ssn_form_ok
    click_idv_continue

    expect(page).to have_content('Jane')
  end

  context 'displays credential errors' do
    it 'triggers an error if the test credentials have a friendly error', allow_browser_log: true do
      triggers_error_test_credentials_missing('spec/fixtures/ial2_test_credential_forces_error.yml', I18n.t('doc_auth.errors.alerts.barcode_content_check').tr(' ', ' '))
    end

    it 'triggers an error if the test credentials missing required address', allow_browser_log: true do
      triggers_error_test_credentials_missing('spec/fixtures/ial2_test_credential_no_address.yml', I18n.t('doc_auth.errors.alerts.address_check').tr(' ', ' '))
    end

    def triggers_error_test_credentials_missing(credential_file, alert_message)
      complete_doc_auth_steps_before_document_capture_step

      attach_file(
        'Front of your ID',
        File.expand_path(credential_file),
      )
      attach_file(
        'Back of your ID',
        File.expand_path(credential_file),
      )
      click_on I18n.t('forms.buttons.submit.default')

      expect(page).to have_content(alert_message)
      expect(page).to have_current_path(idv_document_capture_url)
    end
  end
end
