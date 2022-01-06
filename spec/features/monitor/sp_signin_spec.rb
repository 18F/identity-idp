RSpec.describe 'smoke test: SP initiated sign in' do
  include MonitorIdpSteps
  include MonitorSpSteps

  let(:monitor) { MonitorHelper.new(self) }

  before { monitor.setup }

  context 'OIDC' do
    before { monitor.filter_unless('STAGING') }

    it 'redirects back to SP' do
      visit monitor.idp_signup_url
      email_address, totp_secret = create_new_account_with_totp
      page.first(:link, 'Sign out').click
      visit_idp_from_oidc_sp
      sign_in_and_2fa(email_address, totp_secret)

      click_on 'Agree and continue' if on_consent_screen?

      if monitor.remote?
        expect(page).to have_content('OpenID Connect Sinatra Example')
        expect(current_url).to match(%r{https://(sp|\w+-identity)-oidc-sinatra})
      else
        expect(page).to have_content('OpenID Connect Test Controller')
      end

      log_out_from_oidc_sp
    end
  end

  context 'SAML' do
    before { monitor.filter_if('INT') }

    it 'redirects back to SP' do
      visit monitor.idp_signup_url
      email_address, totp_secret = create_new_account_with_totp
      page.first(:link, 'Sign out').click
      visit_idp_from_saml_sp
      sign_in_and_2fa(email_address, totp_secret)

      click_on 'Agree and continue' if on_consent_screen?

      if monitor.remote?
        expect(page).to have_content('SAML Sinatra Example')
        expect(page).to have_content(email_address)
        expect(current_url).to include(monitor.config.saml_sp_url)
      else
        click_on 'Submit'
        expect(page).to have_content('Decoded SAML Response')
      end

      log_out_from_saml_sp
    end
  end

  def on_consent_screen?
    page.has_content?('been a year since you gave us consent') ||
      page.has_content?('You’ve created an account with') ||
      page.has_content?('You are now signing in for the first time')
  end
end
