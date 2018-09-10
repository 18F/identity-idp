require 'rails_helper'

describe 'redirect_uri validation' do
  include SamlAuthHelper

  context 'when redirect_uri param is included in SAML request' do
    it 'uses the return_to_sp_url URL and not the redirect_uri' do
      allow(FeatureManagement).to receive(:prefill_otp_codes?).and_return(true)
      user = create(:user, :signed_up)
      visit api_saml_auth_path(
        SAMLRequest: CGI.unescape(saml_request(saml_settings)), redirect_uri: 'http://evil.com'
      )
      sp = ServiceProvider.find_by(issuer: 'http://localhost:3000')

      expect(page).
        to have_link t('links.back_to_sp', sp: sp.friendly_name), href: sp.return_to_sp_url

      click_link t('links.sign_in')
      fill_in_credentials_and_submit(user.email, user.password)
      click_submit_default
      click_continue
      click_submit_default

      expect(current_url).to eq sp.acs_url
    end
  end
end
