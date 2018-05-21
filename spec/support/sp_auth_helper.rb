module SpAuthHelper
  def create_loa1_account_go_back_to_sp_and_sign_out(sp)
    allow(FeatureManagement).to receive(:prefill_otp_codes?).and_return(true)
    email = 'test@test.com'
    visit_idp_from_sp_with_loa1(sp)
    click_link t('sign_up.registrations.create_account')
    submit_form_with_valid_email
    click_confirmation_link_in_email(email)
    submit_form_with_valid_password
    set_up_2fa_with_valid_phone
    click_submit_default
    click_acknowledge_personal_key
    click_on t('forms.buttons.continue')
    visit sign_out_url
    User.find_with_email(email)
  end

  def create_loa3_account_go_back_to_sp_and_sign_out(sp)
    allow(FeatureManagement).to receive(:prefill_otp_codes?).and_return(true)
    user = create(:user, :signed_up)
    visit_idp_from_sp_with_loa3(sp)
    click_link t('links.sign_in')
    fill_in_credentials_and_submit(user.email, user.password)
    click_submit_default
    fill_out_idv_jurisdiction_ok
    click_idv_continue
    fill_out_idv_form_ok
    click_idv_continue
    click_idv_address_choose_phone
    fill_out_phone_form_ok(user.phone)
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
