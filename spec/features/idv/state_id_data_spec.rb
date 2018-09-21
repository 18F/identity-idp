require 'rails_helper'

feature 'idv state id data entry' do
  include IdvStepHelper

  let(:locale) { LinkLocaleResolver.locale }

  before do
    start_idv_from_sp
    complete_idv_steps_before_profile_step
    fill_out_idv_form_ok
  end

  it 'renders an error for unverifiable state id number', :email do
    fill_in :profile_state_id_number, with: '000000000'
    click_idv_continue

    expect(page).to have_content t('idv.failure.sessions.warning')
    expect(current_path).to eq(idv_session_failure_path(:warning, locale: locale))
  end

  it 'renders an error for blank state id number and does not attempt to proof', :email do
    expect(Idv::Proofer).to_not receive(:get_vendor)

    fill_in :profile_state_id_number, with: ''
    click_idv_continue

    expect(page).to have_content t('errors.messages.blank')
    expect(current_path).to eq(idv_session_path)
  end

  it 'renders an error for unsupported jurisdiction and does not submit a job', :email do
    expect(Idv::Proofer).to_not receive(:get_vendor)

    select 'Alabama', from: 'profile_state'
    click_idv_continue

    expect(page).to have_content t('idv.errors.unsupported_jurisdiction')
    expect(current_path).to eq(idv_session_path)
  end

  it 'renders an error for a state id that is too long and does not submit a job', :email do
    expect(Idv::Proofer).to_not receive(:get_vendor)

    fill_in 'profile_state_id_number', with: '8' * 26
    click_idv_continue

    expect(page).to have_content t('idv.errors.pattern_mismatch.state_id_number')
    expect(current_path).to eq(idv_session_path)
  end

  it 'allows selection of different state id types', :email do
    choose 'profile_state_id_type_drivers_permit'
    click_idv_continue

    expect(page).to have_content(t('idv.messages.sessions.success'))
    expect(current_path).to eq(idv_session_success_path)
  end
end
