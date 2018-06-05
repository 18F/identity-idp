require 'rails_helper'

class MockSession; end

shared_examples 'saml api' do |cloudhsm_enabled|
  include SamlAuthHelper
  include IdvHelper

  before { enable_cloudhsm(cloudhsm_enabled) }
  after(:all) do
    SamlIdp.configure { |config| SamlIdpEncryptionConfigurator.configure(config, false) }
  end
  let(:user) { create(:user, :signed_up) }

  context 'SAML Assertions' do
    context 'before fully signing in' do
      it 'directs users to the start page' do
        visit authnrequest_get

        expect(current_path).to eq sign_up_start_path
      end

      it 'prompts the user to enter OTP' do
        sign_in_before_2fa(user)
        visit authnrequest_get

        expect(current_path).to eq login_two_factor_path(otp_delivery_preference: 'sms')
      end
    end

    context 'user has not set up 2FA yet and signs in' do
      before do
        sign_in_before_2fa
        visit authnrequest_get
      end

      it 'prompts the user to set up 2FA' do
        expect(current_path).to eq phone_setup_path
      end

      it 'prompts the user to confirm phone after setting up 2FA' do
        fill_in 'Phone', with: '202-555-1212'
        click_send_security_code

        expect(current_path).to eq login_two_factor_path(otp_delivery_preference: 'sms')
      end
    end

    context 'service provider does not explicitly disable encryption' do
      before do
        sign_in_and_2fa_user(user)
        visit sp1_authnrequest
        click_continue
      end

      let(:xmldoc) { SamlResponseDoc.new('feature', 'response_assertion') }

      it 'is encrypted' do
        expect(xmldoc.original_encrypted?).to eq true
      end
    end

    context 'user can get a well-formed signed Assertion' do
      before do
        sign_in_and_2fa_user(user)
        visit authnrequest_get
        click_continue
      end

      let(:xmldoc) { SamlResponseDoc.new('feature', 'response_assertion') }

      it 'renders saml_post_binding template with XML response' do
        expect(page.find('#SAMLResponse', visible: false)).to be_truthy
      end

      it 'contains an assertion nodeset' do
        expect(xmldoc.response_assertion_nodeset.length).to eq(1)
      end

      it 'respects service provider explicitly disabling encryption' do
        expect(xmldoc.original_encrypted?).to eq false
      end

      it 'populates issuer with the idp name' do
        expect(xmldoc.issuer_nodeset.length).to eq(1)
        expect(xmldoc.issuer_nodeset[0].content).to eq("https://#{Figaro.env.domain_name}/api/saml")
      end

      it 'signs the assertion' do
        expect(xmldoc.signature_nodeset.length).to eq(1)
      end

      # Verify http://www.w3.org/2000/09/xmldsig#enveloped-signature
      it 'applies xmldsig enveloped signature correctly' do
        saml_response = xmldoc.saml_response(saml_spec_settings)
        saml_response.soft = false
        expect(saml_response.is_valid?).to eq true
      end

      # Verify http://www.w3.org/2001/10/xml-exc-c14n#
      it 'applies canonicalization method correctly' do
        expect(xmldoc.signature_canon_method_nodeset[0].content).to eq ''
      end

      it 'contains a signature method nodeset with SHA256 algorithm' do
        expect(xmldoc.signature_method_nodeset.length).to eq(1)
        expect(xmldoc.signature_method_nodeset[0].attr('Algorithm')).
          to eq('http://www.w3.org/2001/04/xmldsig-more#rsa-sha256')
      end

      it 'contains a digest method nodeset with SHA256 algorithm' do
        expect(xmldoc.digest_method_nodeset.length).to eq(1)
        expect(xmldoc.digest_method_nodeset[0].attr('Algorithm')).
          to eq('http://www.w3.org/2001/04/xmlenc#sha256')
      end

      it 'redirects to /test/saml/decode_assertion after submitting the form' do
        click_button t('forms.buttons.submit.default')
        expect(page.current_url).
          to eq(saml_spec_settings.assertion_consumer_service_url)
      end

      it 'stores SP identifier in Identity model' do
        expect(user.last_identity.service_provider).to eq saml_spec_settings.issuer
      end

      it 'stores last_authenticated_at in Identity model' do
        expect(user.last_identity.last_authenticated_at).to be_present
      end

      it 'disables cache' do
        expect(page.response_headers['Pragma']).to eq 'no-cache'
      end
    end
  end

  context 'dashboard' do
    let(:fake_dashboard_url) { 'http://dashboard.example.org' }
    let(:dashboard_sp_issuer) { 'some-dashboard-service-provider' }
    let(:dashboard_service_providers) do
      [
        {
          issuer: dashboard_sp_issuer,
          acs_url: 'http://sp.example.org/saml/login',
          cert: saml_test_sp_cert,
          active: true,
        },
      ]
    end

    context 'use_dashboard_service_providers true' do
      before do
        allow(Figaro.env).to receive(:use_dashboard_service_providers).and_return('true')
        allow(Figaro.env).to receive(:dashboard_url).and_return(fake_dashboard_url)
        stub_request(:get, fake_dashboard_url).to_return(
          status: 200,
          body: dashboard_service_providers.to_json
        )
      end

      after { ServiceProvider.from_issuer(dashboard_sp_issuer).destroy }

      it 'updates the service providers in the database' do
        page.driver.header 'X-LOGIN-DASHBOARD-TOKEN', '123ABC'
        expect { page.driver.post '/api/service_provider' }.
          to(change { ServiceProvider.active.sort_by(&:id) })

        expect(page.status_code).to eq 200
      end
    end
  end

  context 'visiting /api/saml/logout' do
    context 'session timed out' do
      let(:logout_user) { create(:user, :signed_up) }

      before do
        sign_in_and_2fa_user(logout_user)
        visit sp1_authnrequest
      end

      it 'redirects to root' do
        Timecop.travel(Devise.timeout_in + 1.second)
        visit destroy_user_session_url
        expect(page.current_path).to eq('/')
        Timecop.return
      end
    end
  end

  context 'SAML secret rotation' do
    before do
      allow(FeatureManagement).to receive(:enable_saml_cert_rotation?).and_return(true)
    end

    let(:new_cert_saml_settings) do
      settings = saml_settings
      settings.idp_sso_target_url = "http://#{Figaro.env.domain_name}/api/saml/auth2018"
      settings.idp_slo_target_url = "http://#{Figaro.env.domain_name}/api/saml/logout2018"
      settings.issuer = 'http://localhost:3000'
      settings.idp_cert_fingerprint = Fingerprinter.fingerprint_cert(new_x509_cert)
      settings
    end

    let(:new_cert_authn_request) do
      auth_request.create(new_cert_saml_settings)
    end

    let(:new_x509_cert) do
      file = File.read(Rails.root.join('certs', 'saml2018.crt.example'))
      OpenSSL::X509::Certificate.new(file)
    end

    context 'for an auth request' do
      it 'creates a valid auth request' do
        sign_in_and_2fa_user(user)
        visit new_cert_authn_request
        click_continue

        response_node = page.find('#SAMLResponse', visible: false)
        decoded_response = Base64.decode64(response_node.value)
        saml_response = OneLogin::RubySaml::Response.new(
          decoded_response,
          settings: new_cert_saml_settings
        )
        saml_response.soft = false

        expect(saml_response.is_valid?).to eq(true)
      end
    end

    context 'for a logout request' do
      it 'create a valid logout request' do
        sign_in_and_2fa_user(user)
        visit new_cert_authn_request
        click_continue

        service_provider = ServiceProvider.from_issuer(new_cert_saml_settings.issuer)
        uuid = user.decorate.active_identity_for(service_provider).uuid
        new_cert_saml_settings = saml_settings
        new_cert_saml_settings.name_identifier_value = uuid

        logout_url = OneLogin::RubySaml::Logoutrequest.new.create(new_cert_saml_settings)
        visit logout_url

        response_node = page.find('#SAMLResponse', visible: false)
        decoded_response = Base64.decode64(response_node.value)
        saml_response = OneLogin::RubySaml::Logoutresponse.new(
          decoded_response,
          new_cert_saml_settings
        )
        expect(saml_response.validate).to eq(true)
      end
    end

    context 'for a metadata request' do
      it 'includes the cert' do
        visit api_saml_metadata2018_path
        document = REXML::Document.new(page.html)
        cert_base64 = REXML::XPath.first(document, '//X509Certificate').text
        expect(cert_base64).to eq(Base64.strict_encode64(new_x509_cert.to_der))
      end

      it 'includes the correct auth and logout urls' do
        visit api_saml_metadata2018_path
        document = REXML::Document.new(page.html)
        auth_node = REXML::XPath.first(document, '//SingleSignOnService')
        logout_node = REXML::XPath.first(document, '//SingleLogoutService')

        expect(auth_node.attributes['Location']).to include(api_saml_auth2018_path)
        expect(logout_node.attributes['Location']).to include(destroy_user_session2018_path)
      end
    end
  end

  def enable_cloudhsm(is_enabled)
    unless is_enabled
      allow(Figaro.env).to receive(:cloudhsm_enabled).and_return('false')
      SamlIdp.configure { |config| SamlIdpEncryptionConfigurator.configure(config, false) }
      return
    end
    allow(Figaro.env).to receive(:cloudhsm_enabled).and_return('true')
    SamlIdp.configure { |config| SamlIdpEncryptionConfigurator.configure(config, true) }
    allow(PKCS11).to receive(:open).and_return('true')
    allow_any_instance_of(SamlIdp::Configurator).to receive_message_chain(:pkcs11, :active_slots, :first, :open).and_yield(MockSession)
    allow(MockSession).to receive(:login).and_return(true)
    allow(MockSession).to receive(:logout).and_return(true)
    allow(MockSession).to receive_message_chain(:find_objects, :first).and_return(true)
    allow(MockSession).to receive(:sign).and_return('')
    allow_any_instance_of(OneLogin::RubySaml::Response).to receive(:is_valid?).and_return(true)
  end
end

feature 'saml' do
  it_behaves_like 'saml api', false
  it_behaves_like 'saml api', true
end
