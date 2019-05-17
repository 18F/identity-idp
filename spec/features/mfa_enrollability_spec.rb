require 'rails_helper'

describe 'TOTP enrollability' do
  before do
    allow(FeatureManagement).to receive(:prefill_otp_codes?).and_return(true)
  end

  let(:user) { create(:user, :signed_up, :with_authentication_app) }

  context 'sign up' do
    it 'does not allow choosing totp as backup auth method after it is used as primary' do
      sign_up_and_set_password

      select_2fa_option('auth_app')
      secret = find('#qr-code').text
      fill_in 'code', with: generate_totp_code(secret)
      click_button 'Submit'

      expect(page).to have_selector('#two_factor_options_form_selection_auth_app', count: 0)
      expect(page).to have_selector('#two_factor_options_form_selection_sms', count: 1)
    end
  end
end
