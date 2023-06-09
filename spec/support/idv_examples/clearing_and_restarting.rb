RSpec.shared_examples 'clearing and restarting idv' do
  it 'allows the user to retry verification with phone', js: true do
    click_on t('idv.messages.clear_and_start_over')
    click_idv_continue

    expect(user.reload.pending_profile?).to eq(false)

    complete_all_doc_auth_steps_before_password_step
    fill_in 'Password', with: user.password
    click_idv_continue
    acknowledge_and_confirm_personal_key

    expect(page).to have_current_path(sign_up_completed_path)
    expect(user.reload.identity_verified?).to eq(true)
  end

  it 'allows the user to retry verification with gpo', js: true do
    click_on t('idv.messages.clear_and_start_over')
    click_idv_continue

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

    gpo_confirmation = GpoConfirmation.order(created_at: :desc).first

    expect(page).to have_content(t('idv.titles.come_back_later'))
    expect(page).to have_current_path(idv_come_back_later_path)
    expect(user.reload.identity_verified?).to eq(false)
    expect(User.find(user.id).pending_profile?).to eq(true)
    expect(gpo_confirmation.entry[:address1]).to eq('1 FAKE RD')
  end

  it 'deletes decrypted PII from the session and does not display it on the account page' do
    click_on t('idv.messages.clear_and_start_over')
    click_idv_continue

    visit account_path

    expect(page).to_not have_content(t('headings.account.profile_info'))
    expect(page).to_not have_content(t('account.index.address'))
    expect(page).to_not have_content(t('account.index.dob'))
    expect(page).to_not have_content(t('account.index.full_name'))
    expect(page).to_not have_content(t('account.index.ssn'))
  end
end
