require 'rails_helper'

feature 'doc auth ssn step', :js do
  include IdvStepHelper
  include DocAuthHelper
  include DocCaptureHelper

  before do
    allow(IdentityConfig.store).
      to receive(:no_sp_device_profiling_enabled).and_return(true)

    sign_in_and_2fa_user
    complete_doc_auth_steps_before_ssn_step
  end

  it 'proceeds to the next page with valid info' do
    fill_out_ssn_form_ok

    match = page.body.match(/session_id=(?<session_id>[^"&]+)/)
    session_id = match && match[:session_id]
    expect(session_id).to be_present

    select 'Review', from: 'mock_profiling_result'

    expect(page.find_field(t('idv.form.ssn_label_html'))['aria-invalid']).to eq('false')
    click_idv_continue

    expect(page).to have_current_path(idv_doc_auth_verify_step)

    profiling_result = Proofing::Mock::DeviceProfilingBackend.new.profiling_result(session_id)
    expect(profiling_result).to eq('review')
  end

  it 'does not proceed to the next page with invalid info' do
    fill_out_ssn_form_fail
    click_idv_continue

    expect(page.find_field(t('idv.form.ssn_label_html'))['aria-invalid']).to eq('true')

    expect(page).to have_current_path(idv_doc_auth_ssn_step)
  end
end
