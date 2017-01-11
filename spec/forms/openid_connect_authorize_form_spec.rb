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
      state: state
    )
  end

  let(:acr_values) do
    [
      Saml::Idp::Constants::LOA1_AUTHN_CONTEXT_CLASSREF,
      Saml::Idp::Constants::LOA3_AUTHN_CONTEXT_CLASSREF
    ].join(' ')
  end

  let(:client_id) { 'urn:gov:gsa:openidconnect:test' }
  let(:nonce) { SecureRandom.hex }
  let(:prompt) { 'select_account' }
  let(:redirect_uri) { 'gov.gsa.openidconnect.test://result' }
  let(:response_type) { 'code' }
  let(:scope) { 'openid profile' }
  let(:state) { SecureRandom.hex }

  describe '#submit' do
    let(:user) { create(:user) }
    let(:rails_session_id) { SecureRandom.hex }
    subject(:result) { form.submit(user, rails_session_id) }

    context 'with valid params' do
      it 'is successful' do
        expect(result[:success]).to eq(true)
        expect(result[:client_id]).to eq(client_id)
      end

      it 'links an identity for this client with the given session id as the code' do
        redirect_uri = URI(result[:redirect_uri])
        code = Rack::Utils.parse_nested_query(redirect_uri.query).with_indifferent_access[:code]
        expect(code).to eq(rails_session_id)

        identity = user.identities.where(service_provider: client_id).first
        expect(identity.session_uuid).to eq(rails_session_id)
        expect(identity.nonce).to eq(nonce)
      end
    end

    context 'with invalid params' do
      let(:response_type) { nil }

      it 'is unsuccessful and has error messages' do
        expect(result[:success]).to eq(false)
        expect(result[:client_id]).to eq(client_id)
        expect(result[:errors]).to be_present
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

    context 'with an unknown client_id' do
      let(:client_id) { 'not_a_real_client_id' }
      it 'has errors' do
        expect(valid?).to eq(false)
        expect(form.errors[:client_id]).
          to include(t('openid_connect.authorization.errors.bad_client_id'))
      end
    end

    context 'without the optional nonce' do
      let(:nonce) { nil }
      it { expect(valid?).to eq(true) }
    end

    context 'when prompt is not select_account' do
      let(:prompt) { 'aaa' }
      it { expect(valid?).to eq(false) }
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
    end

    context 'when response_type is not code' do
      let(:response_type) { 'aaa' }
      it { expect(valid?).to eq(false) }
    end

    context 'without a state' do
      let(:state) { nil }
      it { expect(valid?).to eq(false) }
    end
  end

  describe '#acr_values' do
    let(:acr_values) do
      'http://idmanagement.gov/ns/assurance/loa/1 fake_value'
    end

    it 'is parsed into an array of valid ACR values' do
      expect(form.acr_values).to eq(%w(http://idmanagement.gov/ns/assurance/loa/1))
    end
  end

  describe '#params' do
    it 'is the serialized form values' do
      expect(form.params).to eq(
        acr_values: acr_values,
        client_id: client_id,
        nonce: nonce,
        prompt: prompt,
        redirect_uri: redirect_uri,
        response_type: response_type,
        scope: scope,
        state: state
      )
    end
  end
end
