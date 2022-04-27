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
    fill_out_phone_form_ok(MfaContext.new(user).phone_configurations.detect(&:mfa_enabled?).phone)
    click_idv_continue
    fill_in t('idv.form.password'), with: user.password
    click_continue
    acknowledge_and_confirm_personal_key
    expect(page).to have_current_path(sign_up_completed_path)
    click_agree_and_continue
    visit sign_out_url
    user.reload
  end
end
