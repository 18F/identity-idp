require 'rails_helper'

feature 'Strict IAL2 upgrade', js: true do
  include IdvHelper
  include OidcAuthHelper
  include SamlAuthHelper
  include DocAuthHelper

  before { allow(IdentityConfig.store).to receive(:liveness_checking_enabled).and_return(true) }

  scenario 'an IAL2 strict request for a user with no liveness triggers an upgrade' do
    user = create(
      :profile, :active, :verified,
      pii: { first_name: 'John', ssn: '111223333' }
    ).user
    visit_idp_from_oidc_sp_with_ial2_strict
    sign_in_user(user)
    fill_in_code_with_last_phone_otp
    click_submit_default
    click_agree_and_continue_optional

    expect(page.current_path).to eq(idv_doc_auth_welcome_step)

    complete_all_doc_auth_steps_before_password_step
    fill_in 'Password', with: user.password
    click_continue
    acknowledge_and_confirm_personal_key
    click_agree_and_continue

    expect(current_url).to start_with('http://localhost:7654/auth/result')
    expect(user.active_profile.strict_ial2_proofed?).to be_truthy
  end

  context 'strict IAL2 does not allow a phone check' do
    before do
      allow(IdentityConfig.store).to receive(
        :gpo_allowed_for_strict_ial2,
      ).and_return(false)
    end

    scenario 'an IAL2 strict request for a user without a phone check triggers an upgrade' do
      user = create(
        :profile, :active, :verified,
        pii: { first_name: 'John', ssn: '111223333' },
        proofing_components: { liveness_check: :acuant, address_check: :gpo_letter }
      ).user
      visit_idp_from_oidc_sp_with_ial2_strict
      sign_in_user(user)
      fill_in_code_with_last_phone_otp
      click_submit_default
      click_agree_and_continue_optional

      expect(page.current_path).to eq(idv_doc_auth_welcome_step)

      complete_all_doc_auth_steps_before_password_step
      fill_in 'Password', with: user.password
      click_continue
      acknowledge_and_confirm_personal_key
      click_agree_and_continue

      expect(current_url).to start_with('http://localhost:7654/auth/result')
      expect(user.active_profile.strict_ial2_proofed?).to be_truthy
    end

    scenario 'an IAL2 strict request for a user with a phone check does not trigger an upgrade' do
      user = create(
        :profile, :active, :verified,
        pii: { first_name: 'John', ssn: '111223333' },
        proofing_components: { liveness_check: :acuant, address_check: :lexis_nexis_address }
      ).user
      visit_idp_from_oidc_sp_with_ial2_strict
      sign_in_user(user)
      fill_in_code_with_last_phone_otp
      click_submit_default
      click_agree_and_continue

      expect(current_url).to start_with('http://localhost:7654/auth/result')
      expect(user.active_profile.strict_ial2_proofed?).to be_truthy
    end
  end
end
