require 'rails_helper'

feature 'SP-initiated logout' do
  include SamlAuthHelper
  include IdvHelper

  let(:user) { create(:user, :signed_up) }

  context 'when SP uses embed_sign:false' do
    before do
      sign_in_and_2fa_user(user)
      visit sp1_authnrequest
      click_continue
      sp1 = ServiceProvider.from_issuer(sp1_saml_settings.issuer)
      settings = sp1_saml_settings
      settings.security[:embed_sign] = false
      settings.name_identifier_value = user.decorate.active_identity_for(sp1).uuid

      request = OneLogin::RubySaml::Logoutrequest.new
      visit request.create(settings)
    end

    it 'signs out the user from IdP' do
      visit account_path

      expect(current_path).to eq root_path
    end
  end

  context 'when logged in to a single SP' do
    let(:user) { create(:user, :signed_up) }
    let(:xmldoc) { SamlResponseDoc.new('feature', 'logout_assertion') }

    before do
      sign_in_and_2fa_user(user)
      visit sp1_authnrequest
      click_continue

      sp1 = ServiceProvider.from_issuer(sp1_saml_settings.issuer)
      settings = sp1_saml_settings
      settings.name_identifier_value = user.decorate.active_identity_for(sp1).uuid

      request = OneLogin::RubySaml::Logoutrequest.new
      visit request.create(settings)
    end

    it 'signs out the user from IdP' do
      visit account_path

      expect(current_path).to eq root_path
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

  context 'when logged in to a single SP and using new agency based UUIDs' do
    let(:user) { create(:user, :signed_up) }

    before do
      sign_in_and_2fa_user(user)
      visit sp1_authnrequest

      sp1 = ServiceProvider.from_issuer(sp1_saml_settings.issuer)
      settings = sp1_saml_settings
      settings.name_identifier_value = user.decorate.active_identity_for(sp1).uuid

      request = OneLogin::RubySaml::Logoutrequest.new
      visit request.create(settings)
    end

    it 'signs out the user from IdP' do
      visit account_path

      expect(current_path).to eq root_path
    end
  end

  context 'with multiple SP sessions' do
    let(:user) { create(:user, :signed_up) }
    let(:response_xmldoc) { SamlResponseDoc.new('feature', 'response_assertion') }
    let(:request_xmldoc) { SamlResponseDoc.new('feature', 'request_assertion') }

    before do
      sign_in_and_2fa_user(user)
      visit sp1_authnrequest # sp1
      click_continue

      @sp1_asserted_session_index = response_xmldoc.assertion_statement_node['SessionIndex']
      click_button t('forms.buttons.submit.default')

      visit sp2_authnrequest # sp2
      click_continue
      @sp2_asserted_session_index = response_xmldoc.assertion_statement_node['SessionIndex']
      click_button t('forms.buttons.submit.default')

      sp2 = ServiceProvider.from_issuer(sp2_saml_settings.issuer)
      settings = sp2_saml_settings # sp2
      settings.name_identifier_value = user.decorate.active_identity_for(sp2).uuid

      request = OneLogin::RubySaml::Logoutrequest.new
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

      sp2 = ServiceProvider.from_issuer(sp2_saml_settings.issuer)

      expect(current_url).to eq(sp2.metadata[:assertion_consumer_logout_service_url])
      expect(user.active_identities.size).to eq(0)

      visit account_path
      expect(current_url).to eq root_url
    end
  end

  context 'with multiple SP sessions; non-chronological' do
    let(:user) { create(:user, :signed_up) }
    let(:response_xmldoc) { SamlResponseDoc.new('feature', 'response_assertion') }
    let(:request_xmldoc) { SamlResponseDoc.new('feature', 'request_assertion') }

    before do
      sign_in_and_2fa_user(user)
      visit sp1_authnrequest # sp1
      click_continue

      @sp1_session_index = response_xmldoc.response_session_index_assertion
      click_button t('forms.buttons.submit.default')

      visit sp2_authnrequest # sp2
      click_continue
      @sp2_session_index = response_xmldoc.response_session_index_assertion
      click_button t('forms.buttons.submit.default')

      sp1 = ServiceProvider.from_issuer(sp1_saml_settings.issuer)
      settings = sp1_saml_settings
      settings.name_identifier_value = user.decorate.active_identity_for(sp1).uuid

      request = OneLogin::RubySaml::Logoutrequest.new
      visit request.create(settings) # sp1
    end

    it 'terminates sessions in order of authentication' do
      expect(request_xmldoc.asserted_session_index).to eq(@sp2_session_index)
      click_button t('forms.buttons.submit.default') # LogoutRequest for first SP: sp2

      expect(response_xmldoc.logout_status_assertion).
        to eq('urn:oasis:names:tc:SAML:2.0:status:Success')
      click_button t('forms.buttons.submit.default') # LogoutResponse for originating SP: sp1

      visit account_path

      expect(current_path).to eq root_path
      expect(user.active_identities.size).to eq(0)
    end
  end

  context 'with alternate multiple SP sessions; non-chronological' do
    let(:user) { create(:user, :signed_up) }
    let(:response_xmldoc) { SamlResponseDoc.new('feature', 'response_assertion') }
    let(:request_xmldoc) { SamlResponseDoc.new('feature', 'request_assertion') }

    before do
      sign_in_and_2fa_user(user)
      visit sp2_authnrequest # sp2
      click_continue

      @sp2_session_index = response_xmldoc.response_session_index_assertion
      click_button t('forms.buttons.submit.default')

      visit sp1_authnrequest # sp1
      click_continue
      @sp1_session_index = response_xmldoc.response_session_index_assertion
      click_button t('forms.buttons.submit.default')

      sp2 = ServiceProvider.from_issuer(sp2_saml_settings.issuer)
      settings = sp2_saml_settings
      settings.name_identifier_value = user.decorate.active_identity_for(sp2).uuid

      request = OneLogin::RubySaml::Logoutrequest.new
      visit request.create(settings) # sp2
    end

    it 'terminates sessions in order of authentication' do
      expect(request_xmldoc.asserted_session_index).to eq(@sp1_session_index)
      click_button t('forms.buttons.submit.default') # LogoutRequest for most recent SP: sp1

      expect(response_xmldoc.logout_status_assertion).
        to eq('urn:oasis:names:tc:SAML:2.0:status:Success')
      click_button t('forms.buttons.submit.default') # LogoutResponse for originating SP: sp2

      visit account_path

      expect(current_path).to eq root_path
      expect(user.active_identities.size).to eq(0)

      removed_keys = %w[logout_response logout_response_url]

      expect(page.get_rack_session.keys & removed_keys).to eq []
    end
  end

  context 'with multiple SP sessions in multiple browsers' do
    let(:user) { create(:user, :signed_up) }
    let(:response_xmldoc) { SamlResponseDoc.new('feature', 'response_assertion') }
    let(:request_xmldoc) { SamlResponseDoc.new('feature', 'request_assertion') }

    before do
      perform_in_browser(:browser_one) do
        sign_in_and_2fa_user(user)

        visit sp1_authnrequest # sp1
        click_continue
        @browser_one_sp1_session_index = response_xmldoc.response_session_index_assertion
        click_submit_default

        visit sp2_authnrequest # sp2
        click_continue
        @browser_one_sp2_session_index = response_xmldoc.response_session_index_assertion
        click_submit_default
      end

      perform_in_browser(:browser_two) do
        sign_in_and_2fa_user(user)

        visit sp1_authnrequest # sp1
        @browser_two_sp1_session_index = response_xmldoc.response_session_index_assertion
        click_submit_default

        visit sp2_authnrequest # sp2
        @browser_two_sp2_session_index = response_xmldoc.response_session_index_assertion
        click_submit_default
      end
    end

    it 'terminates sessions in all browsers' do
      expect(user.active_identities.size).to eq(2)

      sp1 = ServiceProvider.from_issuer(sp1_saml_settings.issuer)
      settings = sp1_saml_settings
      settings.name_identifier_value = user.decorate.active_identity_for(sp1).uuid
      sp1_slo_request = OneLogin::RubySaml::Logoutrequest.new
      sp1_slo_request_url = sp1_slo_request.create(settings)

      perform_in_browser(:browser_one) do
        visit sp1_slo_request_url

        expect(request_xmldoc.asserted_session_index).to eq(@browser_two_sp2_session_index)

        click_submit_default
      end

      expect(user.active_identities.size).to eq(0)

      perform_in_browser(:browser_two) do
        visit sp1_slo_request_url

        expect(current_path).to eq root_path
      end
    end
  end

  context 'without SLO implemented at SP' do
    let(:logout_user) { create(:user, :signed_up) }

    before do
      sign_in_and_2fa_user(logout_user)
      visit sp1_authnrequest
      click_continue

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

  context 'logged out of IDP' do
    let(:user) { create(:user, :signed_up) }

    context 'signed into one SP' do
      before do
        sign_in_and_2fa_user(user)
        visit sp1_authnrequest
        click_continue
        sp1 = ServiceProvider.from_issuer(sp1_saml_settings.issuer)
        settings = sp1_saml_settings

        settings.name_identifier_value = user.decorate.active_identity_for(sp1).uuid

        Timecop.travel(Devise.timeout_in + 1.second)

        request = OneLogin::RubySaml::Logoutrequest.new
        visit request.create(settings)
      end

      it 'deactivates the identity' do
        expect(user.active_identities.size).to eq(0)
      end

      it 'redirects to the sp url' do
        assertion_consumer_logout_service_url = 'http://example.com/test/saml/decode_slo_request'

        click_button t('forms.buttons.submit.default')

        expect(current_url).to eq(assertion_consumer_logout_service_url)
      end
    end
  end
end
