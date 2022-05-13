shared_examples 'clearing and restarting idv' do
  it 'allows the user to retry verification with phone', js: true do
    click_on t('idv.messages.clear_and_start_over')

    expect(user.reload.pending_profile?).to eq(false)

    complete_all_doc_auth_steps
    click_idv_continue
    fill_in 'Password', with: user.password
    click_idv_continue
    acknowledge_and_confirm_personal_key

    expect(page).to have_current_path(sign_up_completed_path)
    expect(user.reload.decorate.identity_verified?).to eq(true)
  end

  it 'allows the user to retry verification with gpo', js: true do
    click_on t('idv.messages.clear_and_start_over')

    expect(user.reload.pending_profile?).to eq(false)

    complete_all_doc_auth_steps
    click_on t('idv.troubleshooting.options.verify_by_mail')
    if page.has_button?(t('idv.buttons.mail.send'))
      click_on t('idv.buttons.mail.send')
    else
      click_on t('idv.buttons.mail.resend')
    end
    fill_in 'Password', with: user.password
    click_idv_continue
    acknowledge_and_confirm_personal_key

    gpo_confirmation = GpoConfirmation.order(created_at: :desc).first

    expect(page).to have_content(t('idv.messages.come_back_later', app_name: APP_NAME))
    expect(page).to have_current_path(idv_come_back_later_path)
    expect(user.reload.decorate.identity_verified?).to eq(false)
    expect(user.pending_profile?).to eq(true)
    expect(gpo_confirmation.entry[:address1]).to eq('1 FAKE RD')
  end

  it 'deletes decrypted PII from the session and does not display it on the account page' do
    click_on t('idv.messages.clear_and_start_over')

    visit account_path

    expect(page).to_not have_content(t('headings.account.profile_info'))
    expect(page).to_not have_content(t('account.index.address'))
    expect(page).to_not have_content(t('account.index.dob'))
    expect(page).to_not have_content(t('account.index.full_name'))
    expect(page).to_not have_content(t('account.index.ssn'))
  end
end
