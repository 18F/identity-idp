shared_examples 'clearing and restarting idv' do
  it 'allows the user to retry verification with phone' do
    click_on t('idv.messages.clear_and_start_over')

    expect(user.reload.decorate.pending_profile?).to eq(false)

    fill_out_idv_jurisdiction_ok
    click_idv_continue
    fill_out_idv_form_ok
    fill_in 'profile_address1', with: '8484 Peachtree St'
    click_idv_continue
    click_idv_continue
    click_idv_continue
    fill_in 'Password', with: user.password
    click_idv_continue
    click_acknowledge_personal_key

    expect(page).to have_current_path(sign_up_completed_path)
    expect(user.reload.decorate.identity_verified?).to eq(true)
  end

  it 'allows the user to retry verification with usps' do
    click_on t('idv.messages.clear_and_start_over')

    expect(user.reload.decorate.pending_profile?).to eq(false)

    fill_out_idv_jurisdiction_ok
    click_idv_continue
    fill_out_idv_form_ok
    fill_in 'profile_address1', with: '8484 Peachtree St'
    click_idv_continue
    click_idv_continue
    click_on t('idv.form.activate_by_mail')
    if page.has_button?(t('idv.buttons.mail.send'))
      click_on t('idv.buttons.mail.send')
    else
      click_on t('idv.buttons.mail.resend')
    end
    fill_in 'Password', with: user.password
    click_idv_continue
    click_acknowledge_personal_key

    usps_confirmation = UspsConfirmation.order(created_at: :desc).first

    expect(page).to have_content(t('idv.messages.come_back_later', app: APP_NAME))
    expect(page).to have_current_path(idv_come_back_later_path)
    expect(user.reload.decorate.identity_verified?).to eq(false)
    expect(user.decorate.pending_profile?).to eq(true)
    expect(usps_confirmation.entry[:address1]).to eq('8484 Peachtree St')
  end

  it 'deletes decrypted PII from the session and does not display it on the account page' do
    click_on t('idv.messages.clear_and_start_over')

    visit account_path

    expect(page).to_not have_content(t('heading.account.profile_info'))
    expect(page).to_not have_content(t('account.index.address'))
    expect(page).to_not have_content(t('account.index.dob'))
    expect(page).to_not have_content(t('account.index.full_name'))
    expect(page).to_not have_content(t('account.index.ssn'))
  end
end
