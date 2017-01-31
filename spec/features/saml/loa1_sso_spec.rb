require 'rails_helper'

feature 'LOA1 Single Sign On' do
  include SamlAuthHelper

  context 'First time registration' do
    scenario 'taken to agency handoff page when sign up flow complete' do
      allow(FeatureManagement).to receive(:prefill_otp_codes?).and_return(true)
      saml_authn_request = auth_request.create(saml_settings)

      visit saml_authn_request
      sign_up_and_set_password
      fill_in 'Phone', with: '202-555-1212'
      select_sms_delivery
      enter_2fa_code
      click_acknowledge_recovery_code

      expect(current_url).to eq saml_authn_request
    end

    it 'user is prompted to confirm recovery code before being redirected', js: true do
      allow(FeatureManagement).to receive(:prefill_otp_codes?).and_return(true)
      saml_authn_request = auth_request.create(saml_settings)

      visit saml_authn_request
      sign_up_and_set_password
      fill_in 'Phone', with: '202-555-1212'
      select_sms_delivery
      enter_2fa_code

      acknowledge_and_confirm_recovery_code

      expect(page).to have_content t('titles.loa3_verified.false', app: APP_NAME)
      click_on I18n.t('forms.buttons.continue_to', sp: @sp_name)

      expect(current_url).to eq saml_authn_request
    end
  end
end
