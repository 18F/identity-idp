RSpec.describe 'smoke test: create account' do
  include MonitorIdpSteps
  include MonitorSpSteps
  include MonitorIdvSteps

  let(:monitor) { MonitorHelper.new(self) }

  before { monitor.setup }

  context 'OIDC' do
    context 'not staging' do
      before { monitor.filter_unless('STAGING') }

      skip 'creates new account with SMS option for 2FA' do
        visit_idp_from_oidc_sp

        click_on 'Create an account'
        create_new_account_with_sms

        expect_user_is_redirected_to_oidc_sp

        log_out_from_oidc_sp
      end

      it 'creates new account with TOTP for 2FA' do
        visit_idp_from_oidc_sp
        click_on 'Create an account'
        create_new_account_with_totp

        expect_user_is_redirected_to_oidc_sp

        log_out_from_oidc_sp
      end
    end

    context 'not prod, not staging' do
      before { monitor.filter_unless('PROD', 'STAGING') }

      skip 'creates new IAL2 account with SMS option for 2FA' do
        visit_idp_from_oidc_sp_with_ial2
        verify_identity_with_doc_auth
        expect_user_is_redirected_to_oidc_sp

        log_out_from_oidc_sp
      end
    end
  end

  context 'SAML' do
    before { monitor.filter_if('INT') }

    skip 'creates new account with SMS option for 2FA' do
      visit_idp_from_saml_sp
      click_on 'Create an account'
      email_address = create_new_account_with_sms

      expect_user_is_redirected_to_saml_sp(email_address)

      log_out_from_saml_sp
    end

    it 'creates new account with TOTP for 2FA' do
      visit_idp_from_saml_sp
      click_on 'Create an account'
      email_address, totp_secret = create_new_account_with_totp

      expect_user_is_redirected_to_saml_sp(email_address)

      log_out_from_saml_sp
    end

    skip 'creates new IAL2 account with SMS option for 2FA' do
      visit_idp_from_saml_sp_with_ial2
      verify_identity_with_doc_auth
      expect_user_is_redirected_to_saml_sp(email_address)

      log_out_from_saml_sp
    end
  end

  def expect_user_is_redirected_to_oidc_sp
    expect(page).to have_current_path('/sign_up/completed')

    click_on 'Agree and continue'

    if monitor.remote?
      expect(page).to have_content('OpenID Connect Sinatra Example')
      expect(current_url).to match(%r{https://(sp|\w+-identity)-oidc-sinatra})
    else
      expect(page).to have_content('OpenID Connect Test Controller')
    end
  end

  def expect_user_is_redirected_to_saml_sp(email_address)
    expect(page).to have_current_path('/sign_up/completed')

    click_on 'Agree and continue'

    if monitor.remote?
      expect(page).to have_content('SAML Sinatra Example')
      expect(page).to have_content(email_address)
      expect(current_url).to include(monitor.config.saml_sp_url)
    else
      click_on 'Submit'
      expect(page).to have_content('Decoded SAML Response')
    end
  end
end
