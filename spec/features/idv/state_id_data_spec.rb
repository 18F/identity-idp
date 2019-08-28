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

feature 'idv unsuported state selection' do
  include IdvStepHelper

  let(:locale) { LinkLocaleResolver.locale }

  it 'it allows the SP user to get back to state selection', :email do
    start_idv_from_sp
    complete_idv_steps_before_jurisdiction_step

    select 'Alabama', from: 'jurisdiction_state'
    page.find('#jurisdiction_ial2_consent_given').click
    click_idv_continue

    expect(page).to have_content t('idv.messages.jurisdiction.unsupported_jurisdiction_failure',
                                   state: 'Alabama')

    visit idv_jurisdiction_path
    expect(page).to have_content t('idv.messages.jurisdiction.where')
  end

  it 'it allows the user to get back to state selection', :email do
    sign_in_and_2fa_user
    visit idv_jurisdiction_url

    select 'Alabama', from: 'jurisdiction_state'
    page.find('#jurisdiction_ial2_consent_given').click
    click_idv_continue

    expect(page).to have_content t('idv.messages.jurisdiction.unsupported_jurisdiction_failure',
                                   state: 'Alabama')

    visit idv_jurisdiction_path
    expect(page).to have_content t('idv.messages.jurisdiction.where')
  end

  it 'shows the user a link to get back to their account' do
    sign_in_and_2fa_user
    visit idv_jurisdiction_url

    select 'Alabama', from: 'jurisdiction_state'
    page.find('#jurisdiction_ial2_consent_given').click
    click_idv_continue
    expect(page).to have_content t('links.back_to_account')
  end

  it 'shows the SP user a link to get help from the SP' do
    sp_name = 'Test SP'
    start_idv_from_sp
    complete_idv_steps_before_jurisdiction_step

    select 'Alabama', from: 'jurisdiction_state'
    page.find('#jurisdiction_ial2_consent_given').click
    click_idv_continue
    expect(page).to have_content strip_tags(t('idv.failure.help.get_help_html', sp_name: sp_name))
  end
end
