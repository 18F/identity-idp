RSpec.shared_examples 'clearing and restarting idv' do
  it 'allows the user to retry verification with phone', js: true do
    click_on t('idv.gpo.address_accordion.title')
    expect(page).to have_current_path idv_verify_by_mail_enter_code_path
    click_on t('idv.gpo.address_accordion.cta_link')
    expect(page).to have_current_path idv_confirm_start_over_path
    click_idv_continue
    expect(page).to have_current_path(idv_welcome_path)

    expect(user.reload.pending_profile?).to eq(false)

    complete_all_doc_auth_steps_before_password_step
    fill_in 'Password', with: user.password
    click_idv_continue
    expect(page).to have_current_path idv_personal_key_path
    acknowledge_and_confirm_personal_key

    expect(page).to have_current_path(sign_up_completed_path)
    expect(user.reload.identity_verified?).to eq(true)
  end

  it 'allows the user to retry verification with gpo', js: true do
    click_on t('idv.gpo.address_accordion.title')
    expect(page).to have_current_path idv_verify_by_mail_enter_code_path
    click_on t('idv.gpo.address_accordion.cta_link')
    expect(page).to have_current_path idv_confirm_start_over_path
    click_idv_continue
    expect(page).to have_current_path(idv_welcome_path)

    expect(user.reload.pending_profile?).to eq(false)

    complete_all_doc_auth_steps
    click_on t('idv.troubleshooting.options.verify_by_mail')
    click_on t('idv.buttons.mail.send')
    fill_in 'Password', with: user.password
    click_idv_continue
    expect(page).to have_current_path(idv_letter_enqueued_path)

    gpo_confirmation = GpoConfirmation.order(created_at: :desc).first

    expect(page).to have_content(t('idv.titles.come_back_later'))
    expect(page).to have_current_path(idv_letter_enqueued_path)
    expect(user.reload.identity_verified?).to eq(false)
    expect(User.find(user.id).pending_profile?).to eq(true)
    expect(gpo_confirmation.entry[:address1]).to eq('1 FAKE RD')
  end

  it 'deletes decrypted PII from the session and does not display it on the account page' do
    click_on t('idv.gpo.address_accordion.title')
    click_on t('idv.gpo.address_accordion.cta_link')
    click_idv_continue
    expect(page).to have_current_path(idv_welcome_path)

    visit account_path

    expect(page).to_not have_content(t('account.index.verification.verified_badge'))
    expect(page).to_not have_content(t('account.verified_information.address'))
    expect(page).to_not have_content(t('account.verified_information.dob'))
    expect(page).to_not have_content(t('account.verified_information.full_name'))
    expect(page).to_not have_content(t('account.verified_information.ssn'))
  end
end
