require 'rails_helper'

feature 'doc auth ssn step', :js do
  include IdvStepHelper
  include DocAuthHelper
  include DocCaptureHelper

  before do
    sign_in_and_2fa_user
    complete_doc_auth_steps_before_ssn_step
  end

  it 'proceeds to the next page with valid info' do
    expect_step_indicator_current_step(t('step_indicator.flows.idv.verify_info'))

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

  context 'when verify_info controller is enabled' do
    before do
      allow(IdentityConfig.store).to receive(:doc_auth_verify_info_controller_enabled).
        and_return(true)
    end
    it 'redirects to verify_info controller' do
      fill_out_ssn_form_ok
      click_idv_continue

      expect(page).to have_current_path(idv_verify_info_path)
    end
  end
end
