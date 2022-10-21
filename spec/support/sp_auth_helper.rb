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

  def create_ial2_account_go_back_to_sp_and_sign_out(sp)
    user = create(:user, :signed_up)
    visit_idp_from_sp_with_ial2(sp)
    fill_in_credentials_and_submit(user.email, user.password)
    fill_in_code_with_last_phone_otp
    click_submit_default
    complete_all_doc_auth_steps
    fill_out_phone_form_ok
    click_idv_continue
    choose_idv_otp_delivery_method_sms
    fill_in_code_with_last_phone_otp
    click_submit_default
    fill_in t('idv.form.password'), with: user.password
    click_continue
    acknowledge_and_confirm_personal_key
    expect(page).to have_current_path(sign_up_completed_path)
    click_agree_and_continue
    visit sign_out_url
    user.reload
  end

  def create_in_person_ial2_account_go_back_to_sp_and_sign_out(sp)
    user = user_with_totp_2fa
    ServiceProvider.find_by(issuer: service_provider_issuer(sp)).
      update(in_person_proofing_enabled: true)

    visit_idp_from_sp_with_ial2(sp)
    sign_in_user(user)
    uncheck(t('forms.messages.remember_device'))
    fill_in_code_with_last_totp(user)
    click_submit_default

    expect(page).to have_current_path(idv_doc_auth_welcome_step)
    begin_in_person_proofing
    complete_all_in_person_proofing_steps

    complete_phone_step(user)
    complete_review_step(user)
    acknowledge_and_confirm_personal_key
    expect(page).to have_current_path(idv_in_person_ready_to_verify_path)

    visit sign_out_url
    user.reload

    # Mark IPP as passed
    enrollment = user.in_person_enrollments.last
    expect(enrollment).to_not be_nil
    enrollment.profile.activate
    enrollment.update(status: :passed)

    visit_idp_from_sp_with_ial2(sp)

    sign_in_user(user)
    uncheck(t('forms.messages.remember_device'))
    fill_in_code_with_last_totp(user)
    click_submit_default

    expect(current_path).to eq(sign_up_completed_path)
    click_agree_and_continue

    visit sign_out_url
    user.reload
  end
end
