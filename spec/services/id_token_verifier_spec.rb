require 'rails_helper'

RSpec.describe IdTokenVerifier do
  include Rails.application.routes.url_helpers
  include ActionView::Helpers::TranslationHelper

  subject(:verifier) { IdTokenVerifier.new(http_authorization_header) }
  let(:http_authorization_header) { "Bearer #{id_token}" }

  let(:private_key) { RequestKeyManager.private_key }
  let(:id_token) { JWT.encode(jwt_payload, private_key, 'RS256') }

  let(:identity) { build(:identity) }

  let(:jwt_payload) do
    {
      iss: root_url,
      aud: identity.service_provider,
      sub: identity.uuid,
      jti: 5.minutes.from_now
    }
  end

  describe '#submit' do
    let(:result) { verifier.submit }

    context 'without an authorization header' do
      let(:http_authorization_header) { nil }

      it 'is not successful' do
        expect(result.success?).to eq(false)
        expect(result.errors[:id_token]).
          to include(t('openid_connect.user_info.errors.no_authorization'))
      end
    end

    context 'with a malformed authorization header' do
      let(:http_authorization_header) { 'BOOOO ABCDEF' }

      it 'is not successful' do
        expect(result.success?).to eq(false)
        expect(result.errors[:id_token]).
          to include(t('openid_connect.user_info.errors.malformed_authorization'))
      end
    end

    context 'with an invalid bearer token' do
      let(:id_token) { 'ABDEF' }

      it 'is not successful' do
        expect(result.success?).to eq(false)
        expect(result.errors[:id_token]).to be_present
      end
    end

    context 'with a valid bearer token' do
      before { identity.save! }

      it 'is successful' do
        expect(result.success?).to eq(true)
        expect(result.errors).to be_blank
      end
    end
  end

  describe '#identity' do
    context 'with a valid id_token' do
      before { identity.save! }
      let(:id_token) { IdTokenBuilder.new(identity).id_token }

      it 'returns the identity record' do
        expect(verifier.identity).to eq(identity)
      end
    end

    context 'when the id_token is not a JWT at all' do
      let(:id_token) { 'ABDEF' }

      it 'is nil' do
        expect(verifier.identity).to eq(nil)
      end
    end

    context 'when the subject is wrong' do
      before { jwt_payload[:sub] = 'abcdef' }

      it 'is nil' do
        expect(verifier.identity).to eq(nil)
        expect(verifier.errors[:id_token]).
          to include(t('openid_connect.user_info.errors.not_found'))
      end
    end

    context 'when the audience is wrong' do
      before { jwt_payload[:aud] = 'abcdef' }

      it 'is nil' do
        expect(verifier.identity).to eq(nil)
        expect(verifier.errors[:id_token]).
          to include(t('openid_connect.user_info.errors.not_found'))
      end
    end

    context 'when the issuer is wrong' do
      before { jwt_payload[:iss] = 'abcdef' }

      it 'is nil' do
        expect(verifier.identity).to eq(nil)
        expect(verifier.errors[:id_token]).
          to include("Invalid issuer. Expected #{root_url}, received abcdef")
      end
    end

    context 'when the JWT is signed with the wrong key' do
      let(:private_key) { OpenSSL::PKey::RSA.new(2048) }

      it 'is nil' do
        expect(verifier.identity).to eq(nil)
        expect(verifier.errors[:id_token]).to include('Signature verification raised')
      end
    end

    context 'with the JWT is expired' do
      before { jwt_payload[:exp] = 5.minutes.ago.to_i }

      it 'is nil' do
        expect(verifier.identity).to eq(nil)
        expect(verifier.errors[:id_token]).to include('Signature has expired')
      end
    end
  end
end
