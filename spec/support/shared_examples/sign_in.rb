shared_examples 'signing in with the site in Spanish' do |sp|
  it 'redirects to the SP' do
    allow(FeatureManagement).to receive(:prefill_otp_codes?).and_return(true)
    Capybara.current_session.driver.header('Accept-Language', 'es')

    user = create(:user, :signed_up)
    visit_idp_from_sp_with_loa1(sp)
    click_link t('links.sign_in')
    fill_in_credentials_and_submit(user.email, user.password)

    if sp == :oidc
      expect(page.response_headers['Content-Security-Policy']).
        to(include('form-action \'self\' http://localhost:7654'))
    end

    click_submit_default

    expect(current_url).to eq @saml_authn_request if sp == :saml

    if sp == :oidc
      redirect_uri = URI(current_url)

      expect(redirect_uri.to_s).to start_with('http://localhost:7654/auth/result')
    end
  end
end
