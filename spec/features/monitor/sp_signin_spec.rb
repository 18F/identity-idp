RSpec.describe 'smoke test: SP initiated sign in' do
  include MonitorIdpSteps
  include MonitorSpSteps

  let(:monitor) { MonitorHelper.new(self) }

  before { monitor.setup }

  context 'OIDC' do
    before { monitor.filter_unless('STAGING') }

    it 'redirects back to SP' do
      visit_idp_from_oidc_sp
      sign_in_and_2fa(monitor.config.login_gov_sign_in_email)

      click_on 'Agree and continue' if on_consent_screen?

      if oidc_sp_is_usajobs?
        expect(page).to have_content('Welcome ')
        expect(current_url).to match(%r{https://.*usajobs\.gov})
      elsif monitor.remote?
        expect(page).to have_content('OpenID Connect Sinatra Example')
        expect(current_url).to match(%r{https:\/\/(sp|\w+-identity)\-oidc\-sinatra})
      else
        expect(page).to have_content('OpenID Connect Test Controller')
      end

      log_out_from_oidc_sp
    end
  end

  context 'SAML' do
    before { monitor.filter_if('INT') }

    it 'redirects back to SP' do
      visit_idp_from_saml_sp
      sign_in_and_2fa(monitor.config.login_gov_sign_in_email)

      click_on 'Agree and continue' if on_consent_screen?

      if monitor.remote?
        expect(page).to have_content('SAML Sinatra Example')
        expect(page).to have_content(monitor.config.login_gov_sign_in_email)
        expect(current_url).to include(monitor.config.saml_sp_url)
      else
        click_on 'Submit'
        expect(page).to have_content('Decoded SAML Response')
      end

      log_out_from_saml_sp
    end
  end

  def on_consent_screen?
    page.has_content?("It's been a year since you gave us consent") ||
      page.has_content?('You are now signing in for the first time')
  end
end
