require 'rails_helper'

feature 'Test SP' do
  let(:user) { create(:user, :signed_up) }

  context 'visiting /test/saml' do
    scenario 'it requires 2FA' do
      sign_in_before_2fa(user)
      visit test_saml_path

      expect(current_path).to eq login_two_factor_path(delivery_method: 'sms')
    end

    scenario 'adds acs_url domain names for current Rails env to CSP form_action' do
      sign_in_and_2fa_user(user)
      visit '/test/saml'

      expect(page.response_headers['Content-Security-Policy']).
        to include('form-action \'self\' localhost:3000 example.com')
    end
  end

  scenario 'allows user to visit IDP after login' do
    test_sp_friendly_name_from_config = 'Test SP'
    visit test_saml_path
    sign_up_and_2fa_loa1_user
    click_on I18n.t('forms.buttons.continue_to', sp: test_sp_friendly_name_from_config)

    visit root_path

    expect(current_path).to eq profile_path
  end
end
