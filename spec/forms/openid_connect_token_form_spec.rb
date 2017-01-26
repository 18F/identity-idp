require 'rails_helper'

RSpec.describe OpenidConnectTokenForm do
  include Rails.application.routes.url_helpers

  subject(:form) { OpenidConnectTokenForm.new(params) }

  let(:params) do
    {
      grant_type: grant_type,
      code: code,
      client_id: client_id,
      client_secret: client_secret,
      redirect_uri: redirect_uri
    }
  end

  let(:grant_type) { 'authorization_code' }
  let(:code) { SecureRandom.hex }

  let(:client_id) { 'urn:gov:gsa:openidconnect:test' }
  let(:nonce) { SecureRandom.hex }
  let(:service_provider) { ServiceProvider.new(client_id) }
  let(:client_secret) { service_provider.metadata[:client_secret] }
  let(:redirect_uri) { service_provider.metadata[:redirect_uri] }

  let(:user) { create(:user) }

  before do
    IdentityLinker.new(user, client_id).link_identity(nonce: nonce, session_uuid: code, ial: 1)
  end

  describe '#valid?' do
    subject(:valid?) { form.valid? }

    context 'with valid params' do
      it 'is true, and has no errors' do
        expect(valid?).to eq(true)
        expect(form.errors).to be_blank
      end
    end

    context 'with an incorrect grant_type' do
      let(:grant_type) { 'wrong' }

      it { expect(valid?).to eq(false) }
    end

    context 'with a bad code' do
      before { user.identities.delete_all }

      it 'is invalid' do
        expect(valid?).to eq(false)
        expect(form.errors[:code]).to include(t('openid_connect.token.errors.invalid_code'))
      end
    end
  end

  describe '#submit' do
    subject(:result) { form.submit }

    context 'with valid params' do
      it 'is valid and has no errors' do
        expect(result[:success]).to eq(true)
        expect(result[:errors]).to be_blank
      end

      it 'has the client_id for tracking' do
        expect(result[:client_id]).to eq(client_id)
      end
    end

    context 'with invalid params' do
      let(:code) { nil }

      it 'is invalid and has errors' do
        expect(result[:success]).to eq(false)
        expect(result[:errors]).to be_present
      end
    end
  end

  describe '#response' do
    subject(:response) { form.response }
    let(:server_public_key) { RequestKeyManager.private_key.public_key }

    context 'with valid params' do
      before do
        Pii::SessionStore.new(code).put({}, 5.minutes.to_i)
      end

      it 'has a properly-encoded id_token with an expiration that matches the expires_in' do
        id_token = response[:id_token]

        payload, _head = JWT.decode(id_token, server_public_key, true,
                                    algorithm: 'RS256',
                                    iss: root_url, verify_iss: true,
                                    aud: client_id, verify_aud: true).map(&:with_indifferent_access)

        expect(payload[:nonce]).to eq(nonce)

        expect(response[:expires_in]).to eq(payload[:exp] - Time.zone.now.to_i)
      end

      it 'has an access_token' do
        expect(response[:access_token]).to eq(user.identities.last.access_token)
      end

      it 'specifies its token type' do
        expect(response[:token_type]).to eq('Bearer')
      end
    end

    context 'with invalid params' do
      let(:code) { nil }

      it 'has no id_token' do
        expect(response).to_not have_key(:id_token)
      end

      it 'has an error key in the response' do
        expect(response[:error]).to be_present
      end
    end
  end
end
