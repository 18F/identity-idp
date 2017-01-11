require 'rails_helper'

RSpec.describe OpenidConnectTokenForm do
  include Rails.application.routes.url_helpers

  subject(:form) { OpenidConnectTokenForm.new(params) }

  let(:params) do
    {
      grant_type: grant_type,
      code: code,
      client_assertion_type: client_assertion_type,
      client_assertion: client_assertion
    }
  end

  let(:grant_type) { 'authorization_code' }
  let(:code) { SecureRandom.hex }
  let(:client_assertion_type) { OpenidConnectTokenForm::CLIENT_ASSERTION_TYPE }
  let(:client_assertion) { JWT.encode(jwt_payload, client_private_key, 'RS256') }

  let(:client_id) { 'urn:gov:gsa:openidconnect:test' }
  let(:nonce) { SecureRandom.hex }
  let(:jwt_payload) do
    {
      iss: client_id,
      sub: client_id,
      aud: openid_connect_token_url,
      jti: SecureRandom.hex,
      exp: 5.minutes.from_now.to_i
    }
  end

  let(:client_private_key) { OpenSSL::PKey::RSA.new(Rails.root.join('keys/saml_test_sp.key').read) }
  let(:server_public_key) { RequestKeyManager.private_key.public_key }

  let(:user) { create(:user) }

  before do
    IdentityLinker.new(user, client_id).link_identity(nonce: nonce, session_uuid: code)
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

    context 'with a bad client_assertion_type' do
      let(:grant_type) { 'wrong' }

      it { expect(valid?).to eq(false) }
    end

    context 'with a bad client_assertion' do
      context 'with a bad issuer' do
        before { jwt_payload[:iss] = 'wrong' }

        it 'is invalid' do
          expect(valid?).to eq(false)
          expect(form.errors[:client_assertion]).
            to include("Invalid issuer. Expected #{client_id}, received wrong")
        end
      end

      context 'with a bad subject' do
        before { jwt_payload[:sub] = 'wrong' }

        it 'is invalid' do
          expect(valid?).to eq(false)
          expect(form.errors[:client_assertion]).
            to include("Invalid subject. Expected #{client_id}, received wrong")
        end
      end

      context 'with a bad audience' do
        before { jwt_payload[:exp] = 5.minutes.ago.to_i }

        it 'is invalid' do
          expect(valid?).to eq(false)
          expect(form.errors[:client_assertion]).to include('Signature has expired')
        end
      end

      context 'with an already expired assertion' do
        before { jwt_payload[:exp] = 5.minutes.ago.to_i }

        it 'is invalid' do
          expect(valid?).to eq(false)
          expect(form.errors[:client_assertion]).to include('Signature has expired')
        end
      end

      context 'signed by the wrong key' do
        let(:client_private_key) { OpenSSL::PKey::RSA.new(2048) }

        it 'is invalid' do
          expect(valid?).to eq(false)
          expect(form.errors[:client_assertion]).to include('Signature verification raised')
        end
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

      it 'has a nil client_id when there is insufficient data' do
        expect(result).to include(client_id: nil)
      end
    end
  end

  describe '#response' do
    subject(:response) { form.response }

    context 'with valid params' do
      it 'has a properly-encoded id_token' do
        id_token = response[:id_token]

        payload, _head = JWT.decode(id_token, server_public_key, true,
                                    algorithm: 'RS256',
                                    iss: root_url, verify_iss: true,
                                    aud: client_id, verify_aud: true).map(&:with_indifferent_access)

        expect(payload[:nonce]).to eq(nonce)
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
