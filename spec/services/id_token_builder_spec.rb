require 'rails_helper'

RSpec.describe IdTokenBuilder do
  include Rails.application.routes.url_helpers

  let(:code) { SecureRandom.hex }

  let(:identity) do
    build(:identity,
          nonce: SecureRandom.hex,
          uuid: SecureRandom.uuid,
          ial: 3,
          # this is a known value from an example developer guide
          # https://developer.pingidentity.com/en/resources/openid-connect-developers-guide.html
          access_token: 'dNZX1hEZ9wBCzNL40Upu646bdzQA',
          user: build(:user))
  end

  let(:custom_expiration) { 5.minutes.from_now.to_i }
  subject(:builder) do
    IdTokenBuilder.new(identity: identity, code: code, custom_expiration: custom_expiration)
  end

  describe '#id_token' do
    subject(:id_token) { Timecop.freeze(now) { builder.id_token } }

    let(:now) { Time.zone.now }

    let(:decoded_id_token) do
      JWT.decode(id_token,
                 RequestKeyManager.public_key,
                 true,
                 algorithm: 'RS256').map(&:with_indifferent_access)
    end

    let(:decoded_payload) { decoded_id_token.first }

    it 'sets the issuer to the root url' do
      expect(decoded_payload[:iss]).to eq(root_url)
    end

    it 'sets the audience to the service provider' do
      expect(decoded_payload[:aud]).to eq(identity.service_provider)
    end

    it 'sets the subject as the uuid' do
      expect(decoded_payload[:sub]).to eq(identity.uuid)
    end

    it 'sets the nonce as the nonce' do
      expect(decoded_payload[:nonce]).to eq(identity.nonce)
    end

    it 'sets the acr to the request acr' do
      expect(decoded_payload[:acr]).to eq(Saml::Idp::Constants::LOA3_AUTHN_CONTEXT_CLASSREF)
    end

    it 'sets the jti to something meaningful' do
      expect(decoded_payload[:jti]).to be_present
    end

    context 'without a custom_expiration' do
      let(:custom_expiration) { nil }
      let(:expiration) { 100 }

      before { Pii::SessionStore.new(identity.rails_session_id).put(nil, expiration) }

      it 'sets the expiration to the ttl of the session key in redis' do
        expect(decoded_payload[:exp]).to eq(now.to_i + expiration)
      end
    end

    it 'sets the issued-at to now' do
      expect(decoded_payload[:iat]).to eq(now.to_i)
    end

    it 'sets the not-before to now' do
      expect(decoded_payload[:nbf]).to eq(now.to_i)
    end

    it 'sets the access token hash correctly' do
      # this is a known value from an example developer guide
      # https://developer.pingidentity.com/en/resources/openid-connect-developers-guide.html
      expect(decoded_payload[:at_hash]).to eq('wfgvmE9VxjAudsl9lc6TqA')
    end

    it 'sets the code hash correctly' do
      leftmost_128_bits = Digest::SHA256.digest(code).
                          byteslice(0, IdTokenBuilder::NUM_BYTES_FIRST_128_BITS)
      expected_hash = Base64.urlsafe_encode64(leftmost_128_bits, padding: false)

      expect(decoded_payload[:c_hash]).to eq(expected_hash)
    end

    context 'including attributes allowed by the scope from the request' do
      before { identity.scope = scope }

      context 'without the email scope' do
        let(:scope) { 'openid' }

        it 'does not include the email' do
          expect(decoded_payload).to_not have_key(:email)
        end
      end

      context 'with the email scope' do
        let(:scope) { 'openid email' }

        it 'sets the email' do
          expect(decoded_payload[:email]).to eq(identity.user.email)
        end
      end
    end
  end
end
