require 'rails_helper'

class MockSession; end

feature 'saml api' do
  include SamlAuthHelper
  include IdvHelper

  let(:user) { create(:user, :signed_up) }

  context 'SAML Assertions' do
    context 'before fully signing in' do
      it 'directs users to the start page' do
        visit authnrequest_get

        expect(current_path).to eq new_user_session_path
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
        expect(current_path).to eq two_factor_options_path
      end

      it 'prompts the user to confirm phone after setting up 2FA' do
        select_2fa_option('phone')
        fill_in 'user_phone_form_phone', with: '202-555-1212'
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
          friendly_name: 'Sample Dashboard ServiceProvider',
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
          body: dashboard_service_providers.to_json,
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
        visit api_saml_logout2019_url
        expect(page.current_path).to eq('/')
        Timecop.return
      end
    end
  end
end
