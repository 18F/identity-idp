require 'rails_helper'

feature 'Strict IAL2 with usps upload disallowed', js: true do
  include IdvHelper
  include OidcAuthHelper
  include IdvHelper
  include IdvStepHelper

  before do
    allow(IdentityConfig.store).to receive(:liveness_checking_enabled).and_return(true)
    allow(IdentityConfig.store).to receive(
      :gpo_allowed_for_strict_ial2,
    ).and_return(false)
  end

  it 'does not allow the user to select the letter flow during proofing' do
    user = create(:user, :signed_up)
    visit_idp_from_oidc_sp_with_ial2_strict
    sign_in_user(user)
    fill_in_code_with_last_phone_otp
    click_submit_default
    complete_idv_steps_before_phone_step

    # Link is not present on the phone page
    expect(page).to_not have_content(t('idv.troubleshooting.options.verify_by_mail'))

    # Link is not present on the OTP delivery selection page
    fill_out_phone_form_ok('7032231234')
    click_idv_continue
    expect(page).to_not have_content(t('idv.troubleshooting.options.verify_by_mail'))

    # Link is not visible on the OTP entry page
    choose_idv_otp_delivery_method_sms
    expect(page).to_not have_content(t('idv.troubleshooting.options.verify_by_mail'))

    # Link is not visible on error or warning page
    visit idv_phone_errors_warning_path
    expect(page).to_not have_content(t('idv.troubleshooting.options.verify_by_mail'))
    visit idv_phone_errors_jobfail_path
    expect(page).to_not have_content(t('idv.troubleshooting.options.verify_by_mail'))
    visit idv_phone_errors_timeout_path
    expect(page).to_not have_content(t('idv.troubleshooting.options.verify_by_mail'))
    visit idv_phone_errors_failure_path
    expect(page).to_not have_content(t('idv.troubleshooting.options.verify_by_mail'))

    # Visiting the GPO page redirects
    visit idv_gpo_path
    expect(current_path).to eq(idv_phone_path)
  end

  it 'does not prompt a pending user for a mailed code' do
    user = create(
      :profile,
      deactivation_reason: :gpo_verification_pending,
      pii: { first_name: 'John', ssn: '111223333' },
    ).user

    visit_idp_from_oidc_sp_with_ial2_strict
    sign_in_user(user)
    fill_in_code_with_last_phone_otp
    click_submit_default

    # Directed to the start of the proofing flow instead of GPO code verification
    expect(current_path).to eq(idv_doc_auth_step_path(step: :welcome))

    complete_all_doc_auth_steps_before_password_step
    fill_in 'Password', with: user.password
    click_continue
    acknowledge_and_confirm_personal_key
    click_agree_and_continue

    expect(current_url).to start_with('http://localhost:7654/auth/result')
    expect(user.active_profile.strict_ial2_proofed?).to be_truthy
  end
end
