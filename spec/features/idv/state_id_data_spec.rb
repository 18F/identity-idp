require 'rails_helper'

feature 'idv state id data entry', :idv_job do
  include IdvStepHelper

  before do
    start_idv_from_sp
    complete_idv_steps_before_profile_step
    fill_out_idv_form_ok
  end

  it 'renders an error for unverifiable state id number', :email do
    fill_in :profile_state_id_number, with: '000000000'
    click_idv_continue

    expect(page).to have_content t('idv.modal.sessions.warning')
    expect(current_path).to eq(idv_session_result_path)
  end

  it 'renders an error for blank state id number and does not submit a job', :email do
    expect(Idv::ProoferJob).to_not receive(:perform_now)
    expect(Idv::ProoferJob).to_not receive(:perform_later)

    fill_in :profile_state_id_number, with: ''
    click_idv_continue

    expect(page).to have_content t('errors.messages.blank')
    expect(current_path).to eq(idv_session_path)
  end

  it 'renders an error for unsupported jurisdiction and does not submit a job', :email do
    expect(Idv::ProoferJob).to_not receive(:perform_now)
    expect(Idv::ProoferJob).to_not receive(:perform_later)

    select 'Alabama', from: 'profile_state'
    click_idv_continue

    expect(page).to have_content t('idv.errors.unsupported_jurisdiction')
    expect(current_path).to eq(idv_session_path)
  end

  it 'allows selection of different state id types', :email do
    select t('idv.form.state_id_type.drivers_permit'), from: 'profile_state_id_type'
    click_idv_continue

    success_message = I18n.t(
      'idv.messages.sessions.success',
      pii_message: t('idv.messages.sessions.pii')
    )

    expect(page).to have_content(success_message)
    expect(current_path).to eq(idv_address_path)
  end
end
