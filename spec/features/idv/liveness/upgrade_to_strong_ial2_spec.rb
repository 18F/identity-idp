require 'rails_helper'

describe 'Strong IAL2' do
  include IdvHelper
  include OidcAuthHelper
  include SamlAuthHelper
  include DocAuthHelper

  context 'with an sp that requires livess and a new account' do
    before do
      ServiceProvider.from_issuer('https://rp1.serviceprovider.com/auth/saml/metadata').
        update!(liveness_checking_required: true)
    end

    it 'starts the proofing process if liveness is enabled' do
      allow(AppConfig.env).to receive(:liveness_checking_enabled).and_return('true')

      visit_idp_from_sp_with_ial2(:saml)
      sign_up_and_2fa_ial1_user

      click_agree_and_continue_optional

      expect(page.current_path).to eq(idv_doc_auth_welcome_step)
    end
  end

  context 'with an sp that requires liveness and a current verified profile with no liveness' do
    before do
      ServiceProvider.from_issuer('urn:gov:gsa:openidconnect:sp:server').update!(
        liveness_checking_required: true,
      )
    end

    it 'upgrades user to IAL2 strict if liveness checking is enabled' do
      allow(AppConfig.env).to receive(:liveness_checking_enabled).and_return('true')

      user ||= create(:profile, :active, :verified,
                      pii: { first_name: 'John', ssn: '111223333' }).user
      visit_idp_from_sp_with_ial2(:oidc)
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

    it 'returns an error if liveness checking is disabled' do
      allow(AppConfig.env).to receive(:liveness_checking_enabled).and_return('false')

      visit_idp_from_sp_with_ial2(:oidc)

      expect(current_url).to start_with('http://localhost:7654/auth/result?error=invalid_request'\
'&error_description=Acr+values+Liveness+checking+is+disabled')
    end
  end

  context 'with SP that sends an IAL2 strict request and a verified profile with no liveness' do
    it 'upgrades user to IAL2 strict if liveness checking is enabled' do
      allow(AppConfig.env).to receive(:liveness_checking_enabled).and_return('true')

      user ||= create(:profile, :active, :verified,
                      pii: { first_name: 'John', ssn: '111223333' }).user
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

    it 'returns an error if liveness checking is disabled' do
      allow(AppConfig.env).to receive(:liveness_checking_enabled).and_return('false')

      visit_idp_from_oidc_sp_with_ial2_strict

      expect(current_url).to start_with('http://localhost:7654/auth/result?error=invalid_request'\
'&error_description=Acr+values+Liveness+checking+is+disabled')
    end
  end
end
