require 'rails_helper'

feature 'LOA3 Single Sign On' do
  include SamlAuthHelper
  include IdvHelper

  context 'First time registration' do
    it 'redirects to original SAML Authn Request after IdV is complete' do
      allow(FeatureManagement).to receive(:prefill_otp_codes?).and_return(true)
      saml_authn_request = auth_request.create(loa3_with_bundle_saml_settings)
      visit saml_authn_request

      xmldoc = SamlResponseDoc.new('feature', 'response_assertion')

      visit sign_up_email_path
      user = sign_up_and_set_password
      fill_in 'Phone', with: '202-555-1212'
      select_sms_delivery
      enter_2fa_code

      expect(current_path).to eq verify_path
      click_on 'Yes'
      complete_idv_profile_ok(user.reload)
      click_acknowledge_recovery_code

      expect(current_url).to eq saml_authn_request

      user_access_key = user.unlock_user_access_key(Features::SessionHelper::VALID_PASSWORD)
      profile_phone = user.active_profile.decrypt_pii(user_access_key).phone

      expect(xmldoc.phone_number.children.children.to_s).to eq(profile_phone)
    end
  end
end
