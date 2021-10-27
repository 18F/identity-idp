require 'rails_helper'

feature 'doc auth test credentials', :js do
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

    attach_file 'Front of your ID', File.expand_path('spec/fixtures/ial2_test_credential.yml')
    attach_file 'Back of your ID', File.expand_path('spec/fixtures/ial2_test_credential.yml')
    click_on 'Submit'

    expect(page).to have_current_path(idv_doc_auth_ssn_step)

    fill_out_ssn_form_ok
    click_idv_continue

    expect(page).to have_content('Jane')
  end

  it 'triggers an error if the test credentials have a friendly error', allow_browser_log: true do
    complete_doc_auth_steps_before_document_capture_step

    attach_file(
      'Front of your ID',
      File.expand_path('spec/fixtures/ial2_test_credential_forces_error.yml'),
    )
    attach_file(
      'Back of your ID',
      File.expand_path('spec/fixtures/ial2_test_credential_forces_error.yml'),
    )
    click_on 'Submit'

    expect(page).to have_content(I18n.t('doc_auth.errors.alerts.barcode_content_check'))
    expect(page).to have_current_path(idv_doc_auth_document_capture_step)
  end
end
