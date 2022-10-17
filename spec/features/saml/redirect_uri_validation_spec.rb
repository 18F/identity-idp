require 'rails_helper'

describe 'redirect_uri validation' do
  include SamlAuthHelper

  context 'when redirect_uri param is included in SAML request' do
    it 'uses the return_to_sp_url URL and not the redirect_uri' do
      user = create(:user, :signed_up)
      visit api_saml_auth2022_path(
        SAMLRequest: CGI.unescape(saml_request(saml_settings)),
        redirect_uri: 'http://evil.com',
        state: '123abc',
      )
      sp = ServiceProvider.find_by(issuer: 'http://localhost:3000')

      expect(page).
        to have_link t('links.back_to_sp', sp: sp.friendly_name), href: return_to_sp_cancel_path

      fill_in_credentials_and_submit(user.email, user.password)
      fill_in_code_with_last_phone_otp
      click_submit_default_twice
      click_agree_and_continue
      click_submit_default_twice

      expect(current_url).to eq sp.acs_url
    end
  end
end
