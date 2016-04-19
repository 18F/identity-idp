include SamlAuthHelper
include SamlResponseHelper

feature 'saml api', devise: true, sms: true do
  let(:user) { create(:user, :signed_up, :with_mobile) }

  context 'Unencrypted SAML Assertions' do
    context 'before fully signing in' do
      before { visit authnrequest_get }

      it 'prompts the user to sign in' do
        expect(page).to have_content I18n.t 'devise.failure.unauthenticated'
      end

      it 'prompts the user to enter OTP' do
        sign_in_user(user)
        expect(page).to have_content I18n.t('devise.two_factor_authentication.header_text')
      end
    end

    context 'user can get a well-formed signed Assertion' do
      before do
        visit authnrequest_get
        authenticate_user(user)
      end

      let(:xmldoc) { XmlDoc.new('feature', 'response_assertion') }

      it 'renders saml_post_binding template with XML response' do
        expect(page.find('#SAMLResponse', visible: false)).to be_truthy
      end

      it 'contains an assertion nodeset' do
        expect(xmldoc.response_assertion_nodeset.length).to eq(1)
      end

      it 'populates issuer with the idp name' do
        expect(xmldoc.issuer_nodeset.length).to eq(1)
        expect(xmldoc.issuer_nodeset[0].content).to eq("https://#{Figaro.env.domain_name}/api/saml")
      end

      it 'signs the assertion' do
        expect(xmldoc.signature_nodeset.length).to eq(1)
      end

      # Verify 2 transform algorithms:
      #   http://www.w3.org/2000/09/xmldsig#enveloped-signature
      #   http://www.w3.org/2001/10/xml-exc-c14n#
      # Verify canonicalization algorithm.
      # TODO(awong): Implement.

      it 'contains a signature method nodeset with SHA256 algorithm' do
        expect(xmldoc.signature_method_nodeset.length).to eq(1)
        expect(xmldoc.signature_method_nodeset[0].attr('Algorithm')).
          to eq('http://www.w3.org/2001/04/xmldsig-more#rsa-sha256')
      end

      it 'redirects to /test/saml/decode_assertion after submitting the form' do
        click_button 'Submit'
        expect(page.current_url).
          to eq(saml_spec_settings.assertion_consumer_service_url)
      end

      it 'stores SP identifier in Identity model' do
        expect(user.last_identity.service_provider).to eq saml_spec_settings.issuer
      end

      it 'stores authn_context in Identity model' do
        expect(user.last_identity.authn_context).to eq saml_settings.authn_context
      end

      it 'stores last_authenticated_at in Identity model' do
        expect(user.last_identity.last_authenticated_at).to be_present
      end

      it 'disables cache' do
        expect(page.response_headers['Pragma']).to eq 'no-cache'
      end

      it 'stores provider and authn_context in session' do
        session_hash =
          {
            provider: saml_spec_settings.issuer,
            authn_context: saml_settings.authn_context
          }

        expect(page.get_rack_session_key('sp_data')).to eq(session_hash)
      end

      it 'retains the formatting of the mobile number' do
        expect(xmldoc.mobile_number.children.children.to_s).to eq('+1 (500) 555-0006')
      end
    end
  end

  context 'visiting /test/saml' do
    scenario 'it requires 2FA' do
      sign_in_user
      visit '/test/saml'

      expect(current_path).to eq(users_otp_path)
      expect(page).to have_content(I18n.t('devise.two_factor_authentication.otp_setup'))
    end

    scenario 'it requires security questions' do
      user = create(:user)
      confirm_last_user
      sign_in_user(user)

      # choose OTP delivery
      check 'Email'
      uncheck 'Mobile'
      click_button 'Submit'
      # confirm OTP receipt
      fill_in 'code', with: user.otp_code
      click_button 'Submit'

      visit '/test/saml'

      expect(current_path).to eq(users_questions_path)
      expect(page).to have_content('You must setup your security questions to continue')
    end
  end
end
