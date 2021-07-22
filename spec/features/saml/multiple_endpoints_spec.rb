require 'rails_helper'

describe 'multiple saml endpoints' do
  include SamlAuthHelper
  include IdvHelper

  let(:endpoint_suffix) { '2021' }
  let(:user) { create(:user, :signed_up) }

  let(:endpoint_saml_settings) do
    settings = saml_settings
    settings.idp_sso_target_url =
      "http://#{IdentityConfig.store.domain_name}/api/saml/auth#{endpoint_suffix}"
    settings.idp_slo_target_url =
      "http://#{IdentityConfig.store.domain_name}/api/saml/logout#{endpoint_suffix}"
    settings.issuer = 'http://localhost:3000'
    settings.idp_cert_fingerprint = Fingerprinter.fingerprint_cert(endpoint_cert)
    settings
  end

  let(:endpoint_cert) do
    OpenSSL::X509::Certificate.new(AppArtifacts.store["saml_#{endpoint_suffix}_cert"])
  end

  let(:endpoint_authn_request) { auth_request.create(endpoint_saml_settings) }
  let(:endpoint_metadata_path) { ['/api/saml/metadata', endpoint_suffix].join('') }

  context 'for an auth request' do
    it 'creates a valid auth request' do
      sign_in_and_2fa_user(user)
      visit endpoint_authn_request
      click_agree_and_continue

      response_node = page.find('#SAMLResponse', visible: false)
      decoded_response = Base64.decode64(response_node.value)
      saml_response = OneLogin::RubySaml::Response.new(
        decoded_response,
        settings: endpoint_saml_settings,
      )
      saml_response.soft = false

      expect(saml_response.is_valid?).to eq(true)
    end
  end

  context 'for a logout request' do
    it 'create a valid logout request' do
      sign_in_and_2fa_user(user)
      visit endpoint_authn_request
      click_agree_and_continue

      service_provider = ServiceProvider.find_by(issuer: endpoint_saml_settings.issuer)
      uuid = user.decorate.active_identity_for(service_provider).uuid
      endpoint_saml_settings = saml_settings
      endpoint_saml_settings.name_identifier_value = uuid

      logout_url = OneLogin::RubySaml::Logoutrequest.new.create(endpoint_saml_settings)
      visit logout_url

      response_node = page.find('#SAMLResponse', visible: false)
      decoded_response = Base64.decode64(response_node.value)
      saml_response = OneLogin::RubySaml::Logoutresponse.new(
        decoded_response,
        endpoint_saml_settings,
      )
      expect(saml_response.validate).to eq(true)
    end
  end

  context 'for a metadata request' do
    it 'throws a 404 error with an extension' do
      visit endpoint_metadata_path + '.xml'

      expect(page.status_code).to eq 404
    end

    it 'includes the cert' do
      visit endpoint_metadata_path
      document = REXML::Document.new(page.html)
      cert_base64 = REXML::XPath.first(document, '//X509Certificate').text
      expect(cert_base64).to eq(Base64.strict_encode64(endpoint_cert.to_der))
    end

    it 'includes the correct auth url, and no SingleLogoutService urls' do
      visit endpoint_metadata_path
      document = REXML::Document.new(page.html)
      auth_node = REXML::XPath.first(document, '//SingleSignOnService')
      logout_node = REXML::XPath.first(document, '//SingleLogoutService')

      expect(auth_node.attributes['Location']).to include(
        ['/api/saml/auth', endpoint_suffix].join(''),
      )

      expect(logout_node).to be_nil
    end
  end
end
