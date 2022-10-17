require 'rails_helper'

feature 'signing into an SP with multiple emails enabled' do
  include SamlAuthHelper

  context 'with the email scope' do
    scenario 'signing in with OIDC sends the email address used to sign in' do
      user = create(:user, :signed_up, :with_multiple_emails)
      emails = user.reload.email_addresses.map(&:email)

      expect(emails.count).to eq(2)

      emails.each do |email|
        visit_idp_from_oidc_sp(scope: 'openid email')
        signin(email, user.password)
        fill_in_code_with_last_phone_otp
        click_submit_default
        click_agree_and_continue if current_path == sign_up_completed_path

        decoded_id_token = fetch_oidc_id_token_info
        expect(decoded_id_token[:email]).to eq(email)
        expect(decoded_id_token[:all_emails]).to be_nil

        Capybara.reset_session!
      end
    end

    scenario 'signing in with SAML sends the email address used to sign in' do
      user = create(:user, :signed_up, :with_multiple_emails)
      emails = user.reload.email_addresses.map(&:email)

      expect(emails.count).to eq(2)

      emails.each do |email|
        visit authn_request
        signin(email, user.password)
        fill_in_code_with_last_phone_otp
        click_submit_default_twice
        click_agree_and_continue if current_path == sign_up_completed_path
        click_submit_default

        xmldoc = SamlResponseDoc.new('feature', 'response_assertion')
        email_from_saml_response = xmldoc.attribute_value_for('email')

        expect(email_from_saml_response).to eq(email)

        Capybara.reset_session!
      end
    end
  end

  context 'with the all_emails scope' do
    scenario 'signing in with OIDC sends all emails' do
      user = create(:user, :signed_up, :with_multiple_emails)
      emails = user.reload.email_addresses.map(&:email)

      expect(emails.count).to eq(2)

      visit_idp_from_oidc_sp(scope: 'openid all_emails')
      signin(emails.first, user.password)
      fill_in_code_with_last_phone_otp
      click_submit_default
      click_agree_and_continue

      decoded_id_token = fetch_oidc_id_token_info
      expect(decoded_id_token[:all_emails]).to match_array(emails)
    end

    scenario 'signing in with SAML sends all emails' do
      user = create(:user, :signed_up, :with_multiple_emails)
      emails = user.reload.email_addresses.map(&:email)

      expect(emails.count).to eq(2)

      settings = saml_settings(
        overrides: {
          authn_context: [
            Saml::Idp::Constants::AAL2_AUTHN_CONTEXT_CLASSREF,
            Saml::Idp::Constants::IAL1_AUTHN_CONTEXT_CLASSREF,
            "#{Saml::Idp::Constants::REQUESTED_ATTRIBUTES_CLASSREF}all_emails",
          ],
        },
      )
      visit authn_request(settings)
      signin(emails.first, user.password)
      fill_in_code_with_last_phone_otp
      click_submit_default_twice
      click_agree_and_continue
      click_submit_default

      xmldoc = SamlResponseDoc.new('feature', 'response_assertion')

      emails_from_saml_response = xmldoc.attribute_node_for('all_emails').children.map(&:text)
      expect(emails_from_saml_response).to match_array(emails)
    end
  end

  def visit_idp_from_oidc_sp(scope:)
    visit openid_connect_authorize_path(
      client_id: 'urn:gov:gsa:openidconnect:sp:server',
      response_type: 'code',
      acr_values: Saml::Idp::Constants::IAL1_AUTHN_CONTEXT_CLASSREF,
      scope: scope,
      redirect_uri: 'http://localhost:7654/auth/result',
      state: SecureRandom.hex,
      prompt: 'select_account',
      nonce: SecureRandom.hex,
    )
  end

  def fetch_oidc_id_token_info
    redirect_uri = URI(current_url)
    redirect_params = Rack::Utils.parse_query(redirect_uri.query).with_indifferent_access
    code = redirect_params[:code]

    jwt_payload = {
      iss: 'urn:gov:gsa:openidconnect:sp:server',
      sub: 'urn:gov:gsa:openidconnect:sp:server',
      aud: api_openid_connect_token_url,
      jti: SecureRandom.hex,
      exp: 5.minutes.from_now.to_i,
    }

    client_assertion = JWT.encode(jwt_payload, client_private_key, 'RS256')
    client_assertion_type = 'urn:ietf:params:oauth:client-assertion-type:jwt-bearer'

    page.driver.post(
      api_openid_connect_token_path,
      grant_type: 'authorization_code',
      code: code,
      client_assertion_type: client_assertion_type,
      client_assertion: client_assertion,
    )

    token_response = JSON.parse(page.body).with_indifferent_access
    id_token = token_response[:id_token]
    JWT.decode(id_token, nil, false).first.with_indifferent_access
  end

  def client_private_key
    @client_private_key ||= begin
      OpenSSL::PKey::RSA.new(
        File.read(Rails.root.join('keys', 'saml_test_sp.key')),
      )
    end
  end
end
