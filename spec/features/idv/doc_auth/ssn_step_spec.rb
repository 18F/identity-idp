require 'rails_helper'

RSpec.feature 'ssn step mock proofer', :js do
  include IdvStepHelper
  include DocAuthHelper

  before do
    allow(IdentityConfig.store).to receive(:proofing_device_profiling).and_return(:enabled)
    allow(IdentityConfig.store).to receive(:lexisnexis_threatmetrix_org_id).and_return('test_org')

    sign_in_and_2fa_user
    complete_doc_auth_steps_before_ssn_step
  end

  it 'returns the selected mock proofer result' do
    match = page.body.match(/session_id=(?<session_id>[^"&]+)/)
    session_id = match && match[:session_id]
    expect(session_id).to be_present

    select 'Review', from: 'mock_profiling_result'

    fill_out_ssn_form_ok
    click_idv_continue

    expect(page).to have_current_path(idv_verify_info_url)

    profiling_result = Proofing::Mock::DeviceProfilingBackend.new.profiling_result(session_id)
    expect(profiling_result).to eq('review')
  end
end
