shared_examples 'idv max step attempts' do |sp|
  it 'allows 3 attempts in 24 hours', :email do
    visit_idp_from_sp_with_loa3(sp)
    user = register_user

    max_attempts_less_one.times do
      visit verify_session_path
      fill_out_idv_form_fail
      click_idv_continue

      expect(current_path).to eq verify_session_result_path
    end

    user.reload
    expect(user.idv_attempted_at).to_not be_nil

    fill_out_idv_form_fail
    click_idv_continue

    expect(page).to have_css('.alert-error', text: t('idv.modal.sessions.heading'))

    visit_idp_from_sp_with_loa3(sp)
    expect(page).to have_content(
      t('idv.messages.hardfail', hours: Figaro.env.idv_attempt_window_in_hours)
    )
    expect(current_url).to eq verify_fail_url

    visit verify_session_path
    expect(page).to have_content(t('idv.errors.hardfail'))
    expect(current_url).to eq verify_fail_url

    user.reload
    expect(user.idv_attempted_at).to_not be_nil
  end

  scenario 'profile shows failure flash message after max attempts', :email do
    visit_idp_from_sp_with_loa3(sp)
    register_user

    click_idv_begin

    max_attempts_less_one.times do
      fill_out_idv_form_fail
      click_idv_continue

      expect(current_path).to eq verify_session_result_path
    end

    fill_out_idv_form_fail
    click_idv_continue

    expect(page).to have_css('.alert-error', text: t('idv.modal.sessions.heading'))
    expect(current_path).to eq verify_session_result_path
  end

  scenario 'phone shows failure flash after max attempts', :email do
    visit_idp_from_sp_with_loa3(sp)
    register_user

    click_idv_begin
    fill_out_idv_form_ok
    click_idv_continue
    click_idv_address_choose_phone

    max_attempts_less_one.times do
      fill_out_phone_form_fail
      click_idv_continue

      expect(current_path).to eq verify_phone_result_path
    end

    fill_out_phone_form_fail
    click_idv_continue

    expect(page).to have_css('.alert-error', text: t('idv.modal.phone.heading'))
    expect(current_path).to eq verify_phone_result_path
  end
end
