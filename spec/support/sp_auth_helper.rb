module SpAuthHelper
  def create_loa1_account_go_back_to_sp_and_sign_out(sp)
    email = 'test@test.com'
    visit_idp_from_sp_with_loa1(sp)
    click_link t('links.create_account')
    submit_form_with_valid_email
    click_confirmation_link_in_email(email)
    submit_form_with_valid_password
    set_up_2fa_with_valid_phone
    click_continue
    select_2fa_option('backup_code')
    click_continue
    visit sign_out_url
    User.find_with_email(email)
  end

  def create_loa3_account_go_back_to_sp_and_sign_out(sp)
    user = create(:user, :signed_up)
    visit_idp_from_sp_with_loa3(sp)
    fill_in_credentials_and_submit(user.email, user.password)
    fill_in_code_with_last_phone_otp
    click_submit_default
    fill_out_idv_jurisdiction_ok
    click_idv_continue
    fill_out_idv_form_ok
    click_idv_continue
    click_idv_continue
    fill_out_phone_form_ok(MfaContext.new(user).phone_configurations.detect(&:mfa_enabled?).phone)
    click_idv_continue
    fill_in :user_password, with: user.password
    click_continue
    click_acknowledge_personal_key
    expect(page).to have_current_path(sign_up_completed_path)
    click_on t('forms.buttons.continue')
    visit sign_out_url
    user.reload
  end
end
