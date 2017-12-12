shared_examples 'idv state id data entry' do |sp|
  it 'renders an error for unverifiable state id number', :email do
    visit_idp_from_sp_with_loa3(sp)
    register_user

    visit verify_session_path
    fill_out_idv_form_ok
    fill_in :profile_state_id_number, with: '000000000'
    click_idv_continue

    expect(page).to have_content t('idv.modal.sessions.warning')
    expect(current_path).to eq(verify_session_result_path)
  end

  it 'renders an error for blank state id number and does not submit a job', :email do
    expect(Idv::ProfileJob).to_not receive(:perform_now)
    expect(Idv::ProfileJob).to_not receive(:perform_later)

    visit_idp_from_sp_with_loa3(sp)
    register_user

    visit verify_session_path
    fill_out_idv_form_ok
    fill_in :profile_state_id_number, with: ''
    click_idv_continue

    expect(page).to have_content t('errors.messages.blank')
    expect(current_path).to eq(verify_session_path)
  end

  it 'renders an error for unsupported jurisdiction and does not submit a job', :email do
    expect(Idv::ProfileJob).to_not receive(:perform_now)
    expect(Idv::ProfileJob).to_not receive(:perform_later)

    visit_idp_from_sp_with_loa3(sp)
    register_user

    visit verify_session_path
    fill_out_idv_form_ok
    select 'Alabama', from: 'profile_state'
    click_idv_continue

    expect(page).to have_content t('idv.errors.unsupported_jurisdiction')
    expect(current_path).to eq(verify_session_path)
  end

  it 'allows selection of different state id types', :email do
    visit_idp_from_sp_with_loa3(sp)
    register_user

    visit verify_session_path
    fill_out_idv_form_ok
    select t('idv.form.state_id_type.drivers_permit'), from: 'profile_state_id_type'
    click_idv_continue

    success_message = I18n.t(
      'idv.messages.sessions.success',
      pii_message: t('idv.messages.sessions.pii')
    )

    expect(page).to have_content(success_message)
    expect(current_path).to eq(verify_address_path)
  end
end
