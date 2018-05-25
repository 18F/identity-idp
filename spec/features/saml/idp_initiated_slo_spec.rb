require 'rails_helper'

feature 'IDP-initiated logout' do
  include SamlAuthHelper
  include IdvHelper

  let(:user) { create(:user, :signed_up) }

  context 'when logged in to single SP' do
    let(:user) { create(:user, :signed_up) }
    let(:xmldoc) { SamlResponseDoc.new('feature', 'request_assertion') }
    let(:response_xmldoc) { SamlResponseDoc.new('feature', 'response_assertion') }

    before do
      SamlIdp.configure { |config| SamlIdpEncryptionConfigurator.configure(config, false) }
      sign_in_and_2fa_user(user)
      visit sp1_authnrequest
      click_continue

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
        to include('form-action \'self\' example.com')
    end
  end

  context 'when logged in to multiple SPs' do
    let(:logout_user) { create(:user, :signed_up) }
    let(:response_xmldoc) { SamlResponseDoc.new('feature', 'response_assertion') }
    let(:request_xmldoc) { SamlResponseDoc.new('feature', 'request_assertion') }

    before do
      sign_in_and_2fa_user(logout_user)
      visit sp1_authnrequest
      click_continue

      @sp1_asserted_session_index = response_xmldoc.assertion_statement_node['SessionIndex']

      click_button t('forms.buttons.submit.default')

      visit sp2_authnrequest
      click_continue
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

      visit account_path
      expect(current_path).to eq root_path
    end

    it 'references the correct SessionIndexes' do
      visit destroy_user_session_url

      expect(request_xmldoc.asserted_session_index).to eq(@sp2_asserted_session_index)
      click_button t('forms.buttons.submit.default')

      expect(request_xmldoc.asserted_session_index).to eq(@sp1_asserted_session_index)
      click_button t('forms.buttons.submit.default')
      visit account_path
      expect(current_path).to eq root_path
    end
  end
end
