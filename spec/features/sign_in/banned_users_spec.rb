require 'rails_helper'

feature 'Banning users for an SP' do
  include SamlAuthHelper

  context 'a user is banned from all SPs' do
    it 'does not let the user sign in to any SP' do
      user = create(:user, :signed_up)

      SignInRestriction.create(user: user)

      sign_in_user(user)
      expect_user_to_be_banned

      visit_idp_from_sp_with_ial1(:saml)
      sign_in_user(user)
      expect_user_to_be_banned

      visit_idp_from_sp_with_ial1(:oidc)
      sign_in_user(user)
      expect_user_to_be_banned
    end
  end

  context 'a user is banned for a SAML SP' do
    it 'bans the user from signing in to the banned SP but allows other sign ins' do
      user = create(:user, :signed_up)

      SignInRestriction.create(user: user, service_provider: 'http://localhost:3000')

      sign_in_live_with_2fa(user)
      expect(current_path).to eq(account_path)

      visit_idp_from_sp_with_ial1(:saml)
      expect_user_to_be_banned

      visit_idp_from_sp_with_ial1(:oidc)
      sign_in_live_with_2fa(user)
      click_agree_and_continue
      expect(current_url).to start_with('http://localhost:7654/auth/result')
    end
  end

  context 'a user is banner for an OIDC SP' do
    it 'bans the user from signing in to the banned SP but allows other sign ins' do
      user = create(:user, :signed_up)

      SignInRestriction.create(user: user, service_provider: 'urn:gov:gsa:openidconnect:sp:server')

      sign_in_live_with_2fa(user)
      expect(current_path).to eq(account_path)

      visit_idp_from_sp_with_ial1(:oidc)
      expect_user_to_be_banned

      visit_idp_from_sp_with_ial1(:saml)
      sign_in_live_with_2fa(user)
      click_submit_default
      click_agree_and_continue
      expect(current_path).to eq(complete_saml_path)
    end
  end

  def expect_user_to_be_banned
    expect(current_path).to eq(banned_user_path)
    expect(page).to have_content(I18n.t('banned_user.title'))

    visit account_path
    expect(current_path).to eq(new_user_session_path)
  end
end
