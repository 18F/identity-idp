module SpAuthHelper
  def create_ial1_account_go_back_to_sp_and_sign_out(sp)
    email = 'test@test.com'
    visit_idp_from_sp_with_ial1(sp)
    click_link t('links.create_account')
    submit_form_with_valid_email
    click_confirmation_link_in_email(email)
    submit_form_with_valid_password
    set_up_2fa_with_valid_phone
    visit sign_out_url
    User.find_with_email(email)
  end

  def create_in_person_ial2_account_go_back_to_sp_and_sign_out(sp)
    user = user_with_totp_2fa
    ServiceProvider.find_by(issuer: service_provider_issuer(sp))
      .update(in_person_proofing_enabled: true)

    visit_idp_from_sp_with_ial2(sp)
    sign_in_user(user)
    uncheck(t('forms.messages.remember_device'))
    fill_in_code_with_last_totp(user)
    click_submit_default

    expect(page).to have_current_path(idv_welcome_path)
    begin_in_person_proofing
    complete_all_in_person_proofing_steps

    complete_phone_step(user)
    complete_enter_password_step(user)
    acknowledge_and_confirm_personal_key
    expect(page).to have_current_path(idv_in_person_ready_to_verify_path)

    visit sign_out_url
    user.reload

    mark_in_person_enrollment_passed(user)

    visit_idp_from_sp_with_ial2(sp)

    sign_in_user(user)
    uncheck(t('forms.messages.remember_device'))
    fill_in_code_with_last_totp(user)
    click_submit_default

    expect(page).to have_current_path(sign_up_completed_path)
    click_agree_and_continue

    visit sign_out_url
    user.reload
  end
end
