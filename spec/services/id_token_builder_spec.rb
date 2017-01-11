require 'rails_helper'

RSpec.describe IdTokenBuilder do
  include Rails.application.routes.url_helpers

  let(:identity) do
    build(:identity,
          nonce: SecureRandom.hex,
          uuid: SecureRandom.uuid)
  end

  subject(:builder) { IdTokenBuilder.new(identity) }

  describe '#id_token' do
    subject(:id_token) { Timecop.freeze(now) { builder.id_token } }

    let(:now) { Time.current }

    let(:decoded_id_token) do
      JWT.decode(id_token,
                 RequestKeyManager.private_key.public_key,
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
      pending 'actually setting the acr value'

      expect(decoded_payload[:acr]).to_not eq('')
    end

    it 'sets the jti to something meaningful' do
      pending 'actually setting the jti'

      expect(decoded_payload[:jti]).to_not eq('')
    end

    it 'sets the expiration to something in the future' do
      expect(Time.zone.at(decoded_payload[:exp])).to be > now
    end

    it 'sets the issued-at to now' do
      expect(decoded_payload[:iat]).to eq(now.to_i)
    end

    it 'sets the not-before to now' do
      expect(decoded_payload[:nbf]).to eq(now.to_i)
    end
  end
end
