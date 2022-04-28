require 'rails_helper'

feature 'Strict IAL2 upgrade' do
  include IdvHelper
  include OidcAuthHelper
  include SamlAuthHelper
  include DocAuthHelper

  scenario 'an IAL2 strict request for a user with no liveness triggers an upgrade' do
    allow(IdentityConfig.store).to receive(:liveness_checking_enabled).and_return(true)

    user ||= create(
      :profile, :active, :verified,
      pii: { first_name: 'John', ssn: '111223333' }
    ).user
    visit_idp_from_oidc_sp_with_ial2_strict
    sign_in_user(user)
    fill_in_code_with_last_phone_otp
    click_submit_default
    click_agree_and_continue_optional

    expect(page.current_path).to eq(idv_doc_auth_welcome_step)

    complete_all_doc_auth_steps
    click_continue
    fill_in 'Password', with: user.password
    click_continue
    click_acknowledge_personal_key
    click_agree_and_continue

    expect(current_url).to start_with('http://localhost:7654/auth/result')
    expect(user.active_profile.includes_liveness_check?).to be_truthy
  end
end
