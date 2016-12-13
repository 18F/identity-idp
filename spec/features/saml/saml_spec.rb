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

        expect(current_path).to eq login_two_factor_path(delivery_method: 'sms')
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

        expect(current_path).to eq login_two_factor_path(delivery_method: 'sms')
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

  context 'visiting /api/saml/auth' do
    context 'with LOA3 authn_context' do
      it 'redirects to original SAML Authn Request after IdV is complete' do
        include IdvHelper

        saml_authn_request = auth_request.create(loa3_with_bundle_saml_settings)
        visit saml_authn_request

        xmldoc = SamlResponseDoc.new('feature', 'response_assertion')

        visit sign_up_email_path

        user = sign_up_and_2fa

        expect(current_path).to eq verify_path

        click_on 'Yes'

        complete_idv_profile_ok(user.reload)
        click_acknowledge_recovery_code

        expect(current_url).to eq saml_authn_request

        user_access_key = user.unlock_user_access_key(Features::SessionHelper::VALID_PASSWORD)
        profile_phone = user.active_profile.decrypt_pii(user_access_key).phone

        expect(xmldoc.phone_number.children.children.to_s).to eq(profile_phone)
      end
    end
  end
end
