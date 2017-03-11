require 'rails_helper'

feature 'LOA3 Single Sign On' do
  include SamlAuthHelper
  include IdvHelper

  context 'First time registration' do
    it 'redirects to original SAML Authn Request after IdV is complete' do
      allow(FeatureManagement).to receive(:prefill_otp_codes?).and_return(true)
      saml_authn_request = auth_request.create(loa3_with_bundle_saml_settings)
      xmldoc = SamlResponseDoc.new('feature', 'response_assertion')

      visit saml_authn_request
      visit sign_up_email_path
      user = sign_up_and_set_password
      fill_in 'Phone', with: '202-555-1212'
      select_sms_delivery
      enter_2fa_code

      expect(current_path).to eq verify_path
      click_on 'Yes'
      complete_idv_profile_ok(user.reload)
      click_acknowledge_recovery_code

      expect(page).to have_content t('titles.loa3_verified.true', app: APP_NAME)
      click_on I18n.t('forms.buttons.continue_to', sp: 'Test SP')
      expect(current_url).to eq saml_authn_request

      user_access_key = user.unlock_user_access_key(Features::SessionHelper::VALID_PASSWORD)
      profile_phone = user.active_profile.decrypt_pii(user_access_key).phone

      expect(xmldoc.phone_number.children.children.to_s).to eq(profile_phone)
    end

    it 'shows user the start page with accordion' do
      saml_authn_request = auth_request.create(loa3_with_bundle_saml_settings)

      visit saml_authn_request

      expect(current_path).to match sign_up_start_path
      expect(page).to have_content(t('devise.registrations.start.introduction.loa3_requested.true'))
      expect(page).to have_css('.accordion-header-control',
                               text: t('devise.registrations.start.accordion'))
    end
  end

  context 'canceling verification', js: true do
    it 'returns user to recovery code page if they sign up via loa3' do
      user = create(:user, phone: '1 (111) 111-1111', recovery_code: nil)
      sign_in_with_warden(user)
      loa3_sp_session

      visit verify_path

      click_on t('links.cancel')
      click_on t('idv.buttons.cancel')

      expect(current_path).to eq(manage_recovery_code_path)
    end

    it 'returns user to profile page if they have previously signed up' do
      sign_in_and_2fa_user
      loa3_sp_session

      visit verify_path

      click_on t('links.cancel')
      click_on t('idv.buttons.cancel')
      expect(current_url).to match(/profile/)
    end
  end

  context 'visiting sign_up_completed path before proofing' do
    it 'redirects to verify_path' do
      sign_in_and_2fa_user
      visit loa3_authnrequest

      visit sign_up_completed_path

      expect(current_path).to eq verify_path
    end
  end
end
