require 'rails_helper'

RSpec.describe OpenidConnectAuthorizeForm do
  subject(:form) do
    OpenidConnectAuthorizeForm.new(
      acr_values: acr_values,
      client_id: client_id,
      nonce: nonce,
      prompt: prompt,
      redirect_uri: redirect_uri,
      response_type: response_type,
      scope: scope,
      state: state,
      code_challenge: code_challenge,
      code_challenge_method: code_challenge_method,
      verified_within: verified_within,
    )
  end

  let(:acr_values) do
    [
      Saml::Idp::Constants::IAL1_AUTHN_CONTEXT_CLASSREF,
    ].join(' ')
  end

  let(:client_id) { 'urn:gov:gsa:openidconnect:test' }
  let(:nonce) { SecureRandom.hex }
  let(:prompt) { 'select_account' }
  let(:redirect_uri) { 'gov.gsa.openidconnect.test://result' }
  let(:response_type) { 'code' }
  let(:scope) { 'openid profile' }
  let(:state) { SecureRandom.hex }
  let(:code_challenge) { nil }
  let(:code_challenge_method) { nil }
  let(:verified_within) { nil }

  describe '#submit' do
    subject(:result) { form.submit }

    context 'with valid params' do
      it 'is successful' do
        expect(result.to_h).to eq(
          success: true,
          errors: {},
          client_id: client_id,
          redirect_uri: nil,
          unauthorized_scope: true,
          acr_values: 'http://idmanagement.gov/ns/assurance/ial/1',
          scope: 'openid',
          code_digest: nil,
        )
      end
    end

    context 'with invalid params' do
      context 'with a bad response_type' do
        let(:response_type) { nil }

        it 'is unsuccessful and has error messages' do
          expect(result.to_h).to eq(
            success: false,
            errors: { response_type: ['is not included in the list'] },
            error_details: { response_type: [:inclusion] },
            client_id: client_id,
            redirect_uri: "#{redirect_uri}?error=invalid_request&error_description=" \
                          "Response+type+is+not+included+in+the+list&state=#{state}",
            unauthorized_scope: true,
            acr_values: 'http://idmanagement.gov/ns/assurance/ial/1',
            scope: 'openid',
            code_digest: nil,
          )
        end
      end
    end

    context 'with a bad redirect_uri' do
      let(:redirect_uri) { 'https://wrongurl.com' }

      it 'has errors and does not redirect to the bad redirect_uri' do
        expect(result.errors[:redirect_uri]).
          to include(t('openid_connect.authorization.errors.redirect_uri_no_match'))

        expect(result.extra[:redirect_uri]).to be_nil
      end
    end
  end

  describe '#valid?' do
    subject(:valid?) { form.valid? }

    context 'with all valid attributes' do
      it { expect(valid?).to eq(true) }
      it 'has no errors' do
        valid?
        expect(form.errors).to be_blank
      end
    end

    context 'with no valid acr_values' do
      let(:acr_values) { 'abc def' }
      it 'has errors' do
        expect(valid?).to eq(false)
        expect(form.errors[:acr_values]).
          to include(t('openid_connect.authorization.errors.no_valid_acr_values'))
      end
    end

    context 'with no authorized acr_values' do
      let(:acr_values) { Saml::Idp::Constants::IAL2_AUTHN_CONTEXT_CLASSREF }
      let(:client_id) { 'urn:gov:gsa:openidconnect:test:loa1' }
      it 'has errors' do
        expect(valid?).to eq(false)
        expect(form.errors[:acr_values]).
          to include(t('openid_connect.authorization.errors.no_auth'))
      end
    end

    context 'with aal but not ial requested via acr_values' do
      let(:acr_values) { Saml::Idp::Constants::AAL3_AUTHN_CONTEXT_CLASSREF }
      it 'has errors' do
        expect(valid?).to eq(false)
        expect(form.errors[:acr_values]).
          to include(t('openid_connect.authorization.errors.missing_ial'))
      end
    end

    context 'with an unknown client_id' do
      let(:client_id) { 'not_a_real_client_id' }
      it 'has errors' do
        expect(valid?).to eq(false)
        expect(form.errors[:client_id]).
          to include(t('openid_connect.authorization.errors.bad_client_id'))
      end
    end

    context 'nonce' do
      context 'without a nonce' do
        let(:nonce) { nil }
        it { expect(valid?).to eq(false) }
      end

      context 'with a nonce that is shorter than RANDOM_VALUE_MINIMUM_LENGTH characters' do
        let(:nonce) { '1' * (OpenidConnectAuthorizeForm::RANDOM_VALUE_MINIMUM_LENGTH - 1) }
        it { expect(valid?).to eq(false) }
      end
    end

    context 'when prompt is not select_account or login' do
      let(:prompt) { 'aaa' }
      it { expect(valid?).to eq(false) }
    end

    context 'when prompt is not given' do
      let(:prompt) { nil }
      it { expect(valid?).to eq(true) }
    end

    context 'when prompt is login and allowed by sp' do
      let(:prompt) { 'login' }
      before do
        allow_any_instance_of(ServiceProvider).to receive(:allow_prompt_login).and_return true
      end

      it { expect(valid?).to eq(true) }
    end

    context 'when prompt is login but not allowed by sp' do
      let(:prompt) { 'login' }
      before do
        allow_any_instance_of(ServiceProvider).to receive(:allow_prompt_login).and_return false
      end

      it { expect(valid?).to eq(false) }
    end

    context 'when prompt is blank' do
      let(:prompt) { '' }
      it { expect(valid?).to eq(false) }
    end

    context 'when scope does not contain valid scopes' do
      let(:scope) { 'foo bar baz' }
      it 'has errors' do
        expect(valid?).to eq(false)
        expect(form.errors[:scope]).
          to include(t('openid_connect.authorization.errors.no_valid_scope'))
      end
    end

    context 'when scope is unauthorized and we block unauthorized scopes' do
      let(:scope) { 'email profile' }
      it 'has errors' do
        allow(IdentityConfig.store).to receive(:unauthorized_scope_enabled).and_return(true)
        expect(valid?).to eq(false)
        expect(form.errors[:scope]).
          to include(t('openid_connect.authorization.errors.unauthorized_scope'))
      end
    end

    context 'when scope is good and we block unauthorized scopes' do
      let(:scope) { 'email' }
      it 'does not have errors' do
        allow(IdentityConfig.store).to receive(:unauthorized_scope_enabled).and_return(false)
        expect(valid?).to eq(true)
      end
    end

    context 'when scope is unauthorized and we do not block unauthorized scopes' do
      let(:scope) { 'email profile' }
      it 'does not have errors' do
        allow(IdentityConfig.store).to receive(:unauthorized_scope_enabled).and_return(false)
        expect(valid?).to eq(true)
      end
    end

    context 'when scope includes profile:verified_at but the sp is only ial1' do
      let(:client_id) { 'urn:gov:gsa:openidconnect:test:loa1' }
      let(:acr_values) { Saml::Idp::Constants::IAL1_AUTHN_CONTEXT_CLASSREF }
      let(:scope) { 'email profile:verified_at' }

      it 'has errors' do
        allow(IdentityConfig.store).to receive(:unauthorized_scope_enabled).and_return(true)
        expect(valid?).to eq(false)
        expect(form.errors[:scope]).
          to include(t('openid_connect.authorization.errors.unauthorized_scope'))
      end
    end

    context 'redirect_uri' do
      context 'without a redirect_uri' do
        let(:redirect_uri) { nil }
        it { expect(valid?).to eq(false) }
      end

      context 'with a malformed redirect_uri' do
        let(:redirect_uri) { ':aaaa' }
        it 'has errors' do
          expect(valid?).to eq(false)
          expect(form.errors[:redirect_uri]).
            to include(t('openid_connect.authorization.errors.redirect_uri_invalid'))
        end
      end

      context 'with a redirect_uri not registered to the client' do
        let(:redirect_uri) { 'http://localhost:3000/test' }
        it 'has errors' do
          expect(valid?).to eq(false)
          expect(form.errors[:redirect_uri]).
            to include(t('openid_connect.authorization.errors.redirect_uri_no_match'))
        end
      end

      context 'with a redirect_uri that only partially matches any registered redirect_uri' do
        let(:redirect_uri) { 'gov.gsa.openidconnect.test://result/more/extra' }
        it { expect(valid?).to eq(false) }
      end
    end

    context 'when response_type is not code' do
      let(:response_type) { 'aaa' }
      it { expect(valid?).to eq(false) }
    end

    context 'state' do
      context 'without a state' do
        let(:state) { nil }
        it { expect(valid?).to eq(false) }
      end

      context 'with a state that is shorter than RANDOM_VALUE_MINIMUM_LENGTH characters' do
        let(:state) { '1' * (OpenidConnectAuthorizeForm::RANDOM_VALUE_MINIMUM_LENGTH - 1) }
        it { expect(valid?).to eq(false) }
      end
    end

    context 'PKCE' do
      let(:code_challenge) { 'abcdef' }
      let(:code_challenge_method) { 'S256' }

      context 'code_challenge but no code_challenge_method' do
        let(:code_challenge_method) { nil }
        it 'has errors' do
          expect(valid?).to eq(false)
          expect(form.errors[:code_challenge_method]).to be_present
        end
      end

      context 'bad code_challenge_method' do
        let(:code_challenge_method) { 'plain' }
        it 'has errors' do
          expect(valid?).to eq(false)
          expect(form.errors[:code_challenge_method]).to be_present
        end
      end
    end
  end

  describe '#acr_values' do
    let(:acr_values) do
      [
        'http://idmanagement.gov/ns/assurance/loa/1',
        'http://idmanagement.gov/ns/assurance/aal/3',
        'fake_value',
      ].join(' ')
    end

    it 'is parsed into an array of valid ACR values' do
      expect(form.acr_values).to eq(
        %w[
          http://idmanagement.gov/ns/assurance/loa/1
          http://idmanagement.gov/ns/assurance/aal/3
        ],
      )
    end
  end

  describe '#ial' do
    context 'when IAL1 passed' do
      let(:acr_values) { Saml::Idp::Constants::IAL1_AUTHN_CONTEXT_CLASSREF }

      it 'returns 1' do
        expect(form.ial).to eq(1)
      end
    end

    context 'when IAL2 passed' do
      let(:acr_values) { Saml::Idp::Constants::IAL2_AUTHN_CONTEXT_CLASSREF }

      it 'returns 2' do
        expect(form.ial).to eq(2)
      end
    end

    context 'when IALMAX passed' do
      let(:acr_values) { Saml::Idp::Constants::IALMAX_AUTHN_CONTEXT_CLASSREF }

      it 'returns 0' do
        expect(form.ial).to eq(0)
      end
    end

    context 'when LOA1 passed' do
      let(:acr_values) { Saml::Idp::Constants::LOA1_AUTHN_CONTEXT_CLASSREF }

      it 'returns 1' do
        expect(form.ial).to eq(1)
      end
    end

    context 'when LOA3 passed' do
      let(:acr_values) { Saml::Idp::Constants::LOA3_AUTHN_CONTEXT_CLASSREF }

      it 'returns 2' do
        expect(form.ial).to eq(2)
      end
    end
  end

  describe '#verified_within' do
    context 'without a verified_within' do
      let(:verified_within) { nil }
      it 'is valid' do
        expect(form.valid?).to eq(true)
        expect(form.verified_within).to eq(nil)
      end
    end

    context 'with a duration that is too short (<30 days)' do
      let(:verified_within) { '2d' }
      it 'has errors' do
        expect(form.valid?).to eq(false)
        expect(form.errors[:verified_within]).
          to eq(['value must be at least 30 days or older'])
      end
    end

    context 'with a format in days' do
      let(:verified_within) { '45d' }
      it 'parses the value as a number of days' do
        expect(form.valid?).to eq(true)
        expect(form.verified_within).to eq(45.days)
      end
    end

    context 'with a verified_within with a bad format' do
      let(:verified_within) { 'bbb' }
      it 'has errors' do
        expect(form.valid?).to eq(false)
        expect(form.errors[:verified_within]).to eq(['Unrecognized format for verified_within'])
      end
    end
  end

  describe '#ial2_requested?' do
    subject(:ial2_requested?) { form.ial2_requested? }
    context 'with ial1' do
      let(:acr_values) { Saml::Idp::Constants::IAL1_AUTHN_CONTEXT_CLASSREF }
      it { expect(ial2_requested?).to eq(false) }
    end

    context 'with ial2' do
      let(:acr_values) { Saml::Idp::Constants::IAL2_AUTHN_CONTEXT_CLASSREF }
      it { expect(ial2_requested?).to eq(true) }
    end

    context 'with ial1 and ial2' do
      let(:acr_values) do
        [
          Saml::Idp::Constants::IAL1_AUTHN_CONTEXT_CLASSREF,
          Saml::Idp::Constants::IAL2_AUTHN_CONTEXT_CLASSREF,
        ].join(' ')
      end
      it { expect(ial2_requested?).to eq(true) }
    end

    context 'with a malformed ial' do
      let(:acr_values) { 'foobarbaz' }
      it { expect(ial2_requested?).to eq(false) }
    end
  end

  describe '#client_id' do
    it 'returns the form client_id' do
      form = OpenidConnectAuthorizeForm.new(client_id: 'foobar')

      expect(form.client_id).to eq 'foobar'
    end
  end

  describe '#link_identity_to_service_provider' do
    let(:user) { create(:user) }
    let(:rails_session_id) { SecureRandom.hex }

    context 'with PKCE' do
      let(:code_challenge) { 'abcdef' }
      let(:code_challenge_method) { 'S256' }

      it 'records the code_challenge on the identity' do
        form.link_identity_to_service_provider(user, rails_session_id)

        identity = user.identities.where(service_provider: client_id).first

        expect(identity.code_challenge).to eq(code_challenge)
        expect(identity.nonce).to eq(nonce)
        expect(identity.ial).to eq(1)
      end
    end
  end

  describe '#success_redirect_uri' do
    let(:user) { create(:user) }
    let(:rails_session_id) { SecureRandom.hex }

    context 'when the identity has been linked' do
      before do
        form.link_identity_to_service_provider(user, rails_session_id)
      end

      it 'returns a redirect URI with the code from the identity session_uuid' do
        identity = user.identities.where(service_provider: client_id).first

        expect(form.success_redirect_uri).
          to eq "#{redirect_uri}?code=#{identity.session_uuid}&state=#{state}"
      end

      it 'logs a hash of the code in the analytics params' do
        identity = user.identities.where(service_provider: client_id).first

        code = UriService.params(form.success_redirect_uri)[:code]

        expect(form.submit.extra[:code_digest]).to eq(Digest::SHA256.hexdigest(code))
      end
    end

    context 'when the identity has not been linked' do
      it 'returns nil' do
        expect(form.success_redirect_uri).to be_nil
      end
    end
  end
end
