require 'rails_helper'

include SamlAuthHelper
include IdvHelper

feature 'saml api', devise: true do
  let(:user) { create(:user, :signed_up) }

  context 'SAML Assertions' do
    context 'before fully signing in' do
      it 'prompts the user to sign in' do
        visit authnrequest_get

        expect(current_path).to eq root_path
        expect(page).to have_content t('devise.failure.unauthenticated')
      end

      it 'prompts the user to enter OTP' do
        sign_in_before_2fa(user)
        visit authnrequest_get

        expect(current_path).to eq(user_two_factor_authentication_path)
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
        click_button t('forms.buttons.send_passcode')

        expect(current_path).to eq phone_confirmation_path
      end
    end

    context 'first time registration' do
      before do
        sign_up_and_set_password
        visit authnrequest_get
      end

      it 'prompts user to set up 2FA after confirming email and setting password' do
        expect(current_path).to eq phone_setup_path
      end

      it 'prompts the user to confirm phone after setting up 2FA' do
        fill_in 'Phone', with: '202-555-1212'
        click_button t('forms.buttons.send_passcode')

        expect(current_path).to eq phone_confirmation_path
      end
    end

    context 'service provider does not explicitly disable encryption' do
      before do
        sign_in_and_2fa_user(user)
        visit sp1_authnrequest
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

      it 'retains the formatting of the phone number' do
        expect(xmldoc.phone_number.children.children.to_s).to eq(user.phone)
      end
    end
  end

  context 'visiting /test/saml' do
    scenario 'it requires 2FA' do
      sign_in_before_2fa(user)
      visit '/test/saml'

      expect(current_path).to eq(user_two_factor_authentication_path)
    end

    it 'adds acs_url domain names for current Rails env to CSP form_action' do
      sign_in_and_2fa_user(user)
      visit '/test/saml'

      expect(page.response_headers['Content-Security-Policy']).
        to include('form-action \'self\' localhost:3000 example.com')
    end
  end

  context 'visiting /api/saml/logout' do
    context 'when logged in to single SP with IdP-initiated logout' do
      let(:user) { create(:user, :signed_up) }
      let(:xmldoc) { SamlResponseDoc.new('feature', 'request_assertion') }
      let(:response_xmldoc) { SamlResponseDoc.new('feature', 'response_assertion') }

      before do
        sign_in_and_2fa_user(user)
        visit sp1_authnrequest

        @asserted_session_index = response_xmldoc.assertion_statement_node['SessionIndex']
        visit destroy_user_session_url
      end

      it 'successfully logs the user out' do
        click_button t('forms.buttons.submit.default')
        expect(page).to have_content t('devise.sessions.signed_out')
      end

      it 'generates a signed LogoutRequest' do
        expect(xmldoc.request_assertion).to_not be_nil
      end

      it 'references the correct SessionIndex' do
        expect(xmldoc.logout_asserted_session_index).to eq(@asserted_session_index)
      end

      it 'generates logout request with Issuer' do
        expect(xmldoc.issuer_nodeset.length).to eq(1)
        expect(xmldoc.issuer_nodeset[0].content).to eq "https://#{Figaro.env.domain_name}/api/saml"
      end

      it 'adds acs_url domain names for current Rails env to CSP form_action' do
        expect(page.response_headers['Content-Security-Policy']).
          to include('form-action \'self\' localhost:3000 example.com')
      end
    end

    context 'when logged in to a single SP with SP-initiated logout' do
      let(:user) { create(:user, :signed_up) }
      let(:xmldoc) { SamlResponseDoc.new('feature', 'logout_assertion') }

      before do
        sign_in_and_2fa_user(user)
        visit sp1_authnrequest

        request = OneLogin::RubySaml::Logoutrequest.new
        settings = sp1_saml_settings
        sp1 = ServiceProvider.new(sp1_saml_settings.issuer)
        settings.name_identifier_value = user.decorate.active_identity_for(sp1).uuid

        visit request.create(settings)
      end

      it 'signs out the user from IdP' do
        visit profile_path

        expect(page).to have_content t('devise.failure.unauthenticated')
      end

      it 'contains an issuer nodeset' do
        expect(xmldoc.issuer_nodeset.length).to eq(1)
        expect(xmldoc.issuer_nodeset[0].content).to eq "https://#{Figaro.env.domain_name}/api/saml"
      end

      it 'contains a signature nodeset' do
        expect(xmldoc.signature_nodeset.length).to eq(1)
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

      it 'returns a SAMLResponse' do
        expect(page.find('#SAMLResponse', visible: false)).to be_truthy
      end

      it 'disables cache' do
        expect(page.response_headers['Pragma']).to eq 'no-cache'
      end

      it 'deactivates the identity' do
        expect(user.active_identities.size).to eq(0)
      end
    end

    context 'with authentication at a SP and session times out' do
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

    context 'when logged in to multiple SPs with IdP-initiated logout' do
      let(:logout_user) { create(:user, :signed_up) }
      let(:response_xmldoc) { SamlResponseDoc.new('feature', 'response_assertion') }
      let(:request_xmldoc) { SamlResponseDoc.new('feature', 'request_assertion') }

      before do
        sign_in_and_2fa_user(logout_user)
        visit sp1_authnrequest

        @sp1_asserted_session_index = response_xmldoc.assertion_statement_node['SessionIndex']

        click_button t('forms.buttons.submit.default')

        visit sp2_authnrequest
        @sp2_asserted_session_index = response_xmldoc.assertion_statement_node['SessionIndex']
        click_button t('forms.buttons.submit.default')
      end

      it 'deactivates each authenticated Identity and logs the user out' do
        visit destroy_user_session_url

        click_button t('forms.buttons.submit.default') # logout request for first SP
        click_button t('forms.buttons.submit.default') # logout request for second SP

        logout_user.identities.each do |ident|
          expect(ident.session_uuid).to be_nil
        end

        expect(logout_user.active_identities).to be_empty

        visit profile_path
        expect(page).to have_content t('devise.failure.unauthenticated')
      end

      it 'references the correct SessionIndexes' do
        visit destroy_user_session_url

        expect(request_xmldoc.asserted_session_index).to eq(@sp2_asserted_session_index)
        click_button t('forms.buttons.submit.default')

        expect(request_xmldoc.asserted_session_index).to eq(@sp1_asserted_session_index)
        click_button t('forms.buttons.submit.default')
        visit profile_path
        expect(page).to have_content t('devise.failure.unauthenticated')
      end
    end

    context 'with multiple SP sessions and SP-initiated logout' do
      let(:user) { create(:user, :signed_up) }
      let(:response_xmldoc) { SamlResponseDoc.new('feature', 'response_assertion') }
      let(:request_xmldoc) { SamlResponseDoc.new('feature', 'request_assertion') }

      before do
        sign_in_and_2fa_user(user)
        visit sp1_authnrequest # sp1

        @sp1_asserted_session_index = response_xmldoc.assertion_statement_node['SessionIndex']
        click_button t('forms.buttons.submit.default')

        visit sp2_authnrequest # sp2
        @sp2_asserted_session_index = response_xmldoc.assertion_statement_node['SessionIndex']
        click_button t('forms.buttons.submit.default')

        request = OneLogin::RubySaml::Logoutrequest.new
        settings = sp2_saml_settings # sp2
        sp2 = ServiceProvider.new(sp2_saml_settings.issuer)
        settings.name_identifier_value = user.decorate.active_identity_for(sp2).uuid
        visit request.create(settings)
      end

      it 'deactivates each Identity, asserts correct SessionIndex, and ends session at IdP' do
        expect(user.active_identities.size).to eq(2)

        expect(current_path).to eq('/api/saml/logout')

        expect(request_xmldoc.asserted_session_index).
          to eq(@sp1_asserted_session_index)

        click_button t('forms.buttons.submit.default') # LogoutRequest for first SP

        # SP1 logs user out and responds with success
        # User session is terminated at IdP and success
        # is returned to SP2 (originating requestor)
        expect(response_xmldoc.logout_status_assertion).
          to eq('urn:oasis:names:tc:SAML:2.0:status:Success')

        click_button t('forms.buttons.submit.default') # LogoutResponse for originating SP

        sp2 = ServiceProvider.new(sp2_saml_settings.issuer)

        expect(current_url).to eq(sp2.metadata[:assertion_consumer_logout_service_url])
        expect(user.active_identities.size).to eq(0)

        visit profile_path
        expect(current_url).to eq root_url
      end
    end

    context 'with multiple SP sessions and SP-initiated logout; non-chronological' do
      let(:user) { create(:user, :signed_up) }
      let(:response_xmldoc) { SamlResponseDoc.new('feature', 'response_assertion') }
      let(:request_xmldoc) { SamlResponseDoc.new('feature', 'request_assertion') }

      before do
        sign_in_and_2fa_user(user)
        visit sp1_authnrequest # sp1

        @sp1_session_index = response_xmldoc.response_session_index_assertion
        click_button t('forms.buttons.submit.default')

        visit sp2_authnrequest # sp2
        @sp2_session_index = response_xmldoc.response_session_index_assertion
        click_button t('forms.buttons.submit.default')

        request = OneLogin::RubySaml::Logoutrequest.new
        settings = sp1_saml_settings
        sp1 = ServiceProvider.new(sp1_saml_settings.issuer)
        settings.name_identifier_value = user.decorate.active_identity_for(sp1).uuid
        visit request.create(settings) # sp1
      end

      it 'terminates sessions in order of authentication' do
        expect(request_xmldoc.asserted_session_index).to eq(@sp2_session_index)
        click_button t('forms.buttons.submit.default') # LogoutRequest for first SP: sp2

        expect(response_xmldoc.logout_status_assertion).
          to eq('urn:oasis:names:tc:SAML:2.0:status:Success')
        click_button t('forms.buttons.submit.default') # LogoutResponse for originating SP: sp1

        visit profile_path
        expect(page).to have_content t('devise.failure.unauthenticated')

        expect(user.active_identities.size).to eq(0)
      end
    end

    context 'with alternate multiple SP sessions and SP-initiated logout; non-chronological' do
      let(:user) { create(:user, :signed_up) }
      let(:response_xmldoc) { SamlResponseDoc.new('feature', 'response_assertion') }
      let(:request_xmldoc) { SamlResponseDoc.new('feature', 'request_assertion') }

      before do
        sign_in_and_2fa_user(user)
        visit sp2_authnrequest # sp2

        @sp2_session_index = response_xmldoc.response_session_index_assertion
        click_button t('forms.buttons.submit.default')

        visit sp1_authnrequest # sp1
        @sp1_session_index = response_xmldoc.response_session_index_assertion
        click_button t('forms.buttons.submit.default')

        request = OneLogin::RubySaml::Logoutrequest.new
        settings = sp2_saml_settings
        sp2 = ServiceProvider.new(sp2_saml_settings.issuer)
        settings.name_identifier_value = user.decorate.active_identity_for(sp2).uuid
        visit request.create(settings) # sp2
      end

      it 'terminates sessions in order of authentication' do
        expect(request_xmldoc.asserted_session_index).to eq(@sp1_session_index)
        click_button t('forms.buttons.submit.default') # LogoutRequest for most recent SP: sp1

        expect(response_xmldoc.logout_status_assertion).
          to eq('urn:oasis:names:tc:SAML:2.0:status:Success')
        click_button t('forms.buttons.submit.default') # LogoutResponse for originating SP: sp2

        visit profile_path
        expect(page).to have_content t('devise.failure.unauthenticated')

        expect(user.active_identities.size).to eq(0)

        removed_keys = %w(logout_response logout_response_url)

        expect(page.get_rack_session.keys & removed_keys).to eq []
      end
    end

    context 'without SLO implemented at SP' do
      let(:logout_user) { create(:user, :signed_up) }

      before do
        sign_in_and_2fa_user(logout_user)
        visit sp1_authnrequest

        click_button t('forms.buttons.submit.default')
      end

      it 'completes logout at IdP' do
        allow_any_instance_of(ServiceProvider).to receive(:metadata).and_return(
          service_provider: 'https://rp1.serviceprovider.com/auth/saml/metadata'
        )

        visit destroy_user_session_url

        expect(current_path).to eq('/')
      end
    end
  end

  context 'visiting /api/saml/auth' do
    context 'with LOA3 authn_context' do
      it 'redirects to IdV URL after user creates their account and signs in' do
        visit loa3_authnrequest

        visit new_user_registration_path

        sign_up_and_2fa

        expect(current_url).to eq idv_url
      end

      it 'redirects to original SAML Authn Request after IdV is complete' do
        saml_authn_request = loa3_authnrequest
        visit saml_authn_request

        visit new_user_registration_path

        sign_up_and_2fa

        expect(current_url).to eq idv_url

        click_on 'Yes'

        expect(page).to have_content(t('idv.form.first_name'))

        fill_out_idv_form_ok
        click_button t('forms.buttons.submit.continue')
        fill_out_financial_form_ok
        click_button t('idv.messages.finance.continue')
        click_button t('forms.buttons.submit.continue')
        fill_in :user_password, with: Features::SessionHelper::VALID_PASSWORD
        click_button t('forms.buttons.submit.default')

        expect(current_url).to eq saml_authn_request
      end
    end
  end
end
