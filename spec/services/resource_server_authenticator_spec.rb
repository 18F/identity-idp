require 'rails_helper'

RSpec.describe ResourceServerAuthenticator do
  include Rails.application.routes.url_helpers

  let(:audience) { api_openid_connect_token_url }
  let(:other_endpoint) { api_openid_connect_userinfo_url }
  let(:key_source) { :service_provider }
  let(:service_provider) do
    create(:service_provider, :active, certs: ['saml_test_sp2', 'saml_test_sp'])
  end
  let(:client_id) { service_provider.issuer }
  let(:claims) { {} }
  let(:signing_key) { saml_test_sp_private_key }
  let(:client_assertion) do
    build_client_assertion(client_id:, audience:, key: signing_key, **claims)
  end

  subject(:result) do
    described_class.new(client_assertion:, audience:, key_source:).call
  end

  it 'rejects an unknown key source' do
    expect do
      described_class.new(client_assertion:, audience:, key_source: :nope)
    end.to raise_error(ArgumentError)
  end

  context 'with a valid assertion signed by one of the registered certificates' do
    it 'authenticates and returns the service provider' do
      expect(result.success?).to eq(true)
      expect(result.record).to eq(service_provider)
      expect(result.claimed_identifier).to eq(client_id)
      expect(result.error_type).to be_nil
    end

    it 'tries every certificate on the record' do
      other_key_result = described_class.new(
        client_assertion: build_client_assertion(
          client_id:, audience:, key: saml_test_sp2_private_key,
        ),
        audience:, key_source:
      ).call
      expect(other_key_result.success?).to eq(true)
    end

    it 'accepts an audience that differs only by a trailing slash' do
      with_slash = described_class.new(
        client_assertion: build_client_assertion(client_id:, audience: "#{audience}/"),
        audience: "#{audience}/",
        key_source:,
      ).call
      expect(with_slash.success?).to eq(true)
    end

    it 'accepts an assertion without iat as long as exp is within five minutes' do
      no_iat = described_class.new(
        client_assertion: build_client_assertion(
          client_id:, audience:, iat: nil, exp: 4.minutes.from_now.to_i,
        ),
        audience:, key_source:
      ).call
      expect(no_iat.success?).to eq(true)
    end
  end

  context 'when the assertion is missing' do
    let(:client_assertion) { nil }

    it 'fails with client_assertion_missing' do
      expect(result.success?).to eq(false)
      expect(result.record).to be_nil
      expect(result.error_type).to eq(:client_assertion_missing)
      expect(result.error_message)
        .to eq(t('openid_connect.token.errors.client_assertion_missing'))
    end
  end

  context 'when the assertion is not a JWT' do
    let(:client_assertion) { 'not.a.jwt' }

    it 'fails with client_assertion_malformed' do
      expect(result.error_type).to eq(:client_assertion_malformed)
      expect(result.error_message)
        .to eq(t('openid_connect.token.errors.client_assertion_malformed'))
    end
  end

  context 'when iss and sub differ' do
    let(:claims) { { sub: 'someone-else' } }

    it 'fails with client_assertion_malformed' do
      expect(result.error_type).to eq(:client_assertion_malformed)
    end
  end

  context 'when iss names no registered caller' do
    let(:client_id) { 'urn:gov:gsa:openidconnect:nobody' }

    it 'fails with unknown_client and reports the claimed identifier' do
      expect(result.error_type).to eq(:unknown_client)
      expect(result.claimed_identifier).to eq(client_id)
      expect(result.error_message).to eq(t('openid_connect.token.errors.unknown_client'))
    end
  end

  context 'when the signature does not match any registered certificate' do
    let(:signing_key) { OpenSSL::PKey::RSA.new(2048) }

    it 'fails with invalid_signature and the library message' do
      expect(result.error_type).to eq(:invalid_signature)
      expect(result.error_message).to eq('Signature verification failed')
    end
  end

  context 'when the record has no certificates' do
    before { service_provider.update!(certs: []) }

    it 'fails with invalid_signature and the generic message' do
      expect(result.error_type).to eq(:invalid_signature)
      expect(result.error_message).to eq(t('openid_connect.token.errors.invalid_signature'))
    end
  end

  context 'when the assertion is signed with an algorithm other than RS256' do
    let(:client_assertion) do
      payload = {
        iss: client_id,
        sub: client_id,
        aud: audience,
        jti: SecureRandom.hex,
        iat: Time.zone.now.to_i,
        exp: 1.minute.from_now.to_i,
      }
      JWT.encode(payload, 'shared-secret', 'HS256')
    end

    it 'fails with invalid_signature' do
      expect(result.success?).to eq(false)
      expect(result.error_type).to eq(:invalid_signature)
    end
  end

  context 'when exp is missing' do
    let(:claims) { { exp: nil } }

    it 'fails with client_assertion_missing_claim' do
      expect(result.error_type).to eq(:client_assertion_missing_claim)
      expect(result.error_message).to include('exp')
    end
  end

  context 'when jti is missing' do
    let(:claims) { { jti: nil } }

    it 'fails with client_assertion_missing_claim' do
      expect(result.error_type).to eq(:client_assertion_missing_claim)
    end
  end

  context 'when the assertion has expired' do
    let(:claims) { { iat: 10.minutes.ago.to_i, exp: 5.minutes.ago.to_i } }

    it 'fails with client_assertion_expired' do
      expect(result.error_type).to eq(:client_assertion_expired)
    end
  end

  context 'when aud is a different endpoint' do
    let(:claims) { { aud: other_endpoint } }

    it 'fails with invalid_aud and names the expected URL' do
      expect(result.error_type).to eq(:invalid_aud)
      expect(result.error_message)
        .to eq(t('openid_connect.token.errors.invalid_aud', url: audience))
    end
  end

  context 'when aud is an array containing the endpoint' do
    let(:claims) { { aud: ['https://other.example.gov/', audience] } }

    it 'authenticates' do
      expect(result.success?).to eq(true)
    end
  end

  context 'when iat is in the future beyond the leeway' do
    let(:claims) { { iat: 1.minute.from_now.to_i, exp: 2.minutes.from_now.to_i } }

    it 'fails with invalid_iat' do
      expect(result.error_type).to eq(:invalid_iat)
      expect(result.error_message).to eq(t('openid_connect.token.errors.invalid_iat'))
    end
  end

  context 'when iat is a few seconds in the future within the leeway' do
    let(:claims) { { iat: 5.seconds.from_now.to_i, exp: 1.minute.from_now.to_i } }

    it 'authenticates' do
      expect(result.success?).to eq(true)
    end
  end

  context 'when exp is more than five minutes after iat' do
    let(:claims) { { iat: Time.zone.now.to_i, exp: 6.minutes.from_now.to_i } }

    it 'fails with client_assertion_lifetime' do
      expect(result.error_type).to eq(:client_assertion_lifetime)
      expect(result.error_message)
        .to eq(t('openid_connect.token.errors.client_assertion_lifetime'))
    end
  end

  context 'when exp is more than five minutes away and iat is absent' do
    let(:claims) { { iat: nil, exp: 6.minutes.from_now.to_i } }

    it 'fails with client_assertion_lifetime' do
      expect(result.error_type).to eq(:client_assertion_lifetime)
    end
  end

  context 'when the same jti is presented twice' do
    it 'accepts the first use and rejects the replay' do
      first = described_class.new(client_assertion:, audience:, key_source:).call
      second = described_class.new(client_assertion:, audience:, key_source:).call

      expect(first.success?).to eq(true)
      expect(second.success?).to eq(false)
      expect(second.error_type).to eq(:client_assertion_replayed)
      expect(second.error_message)
        .to eq(t('openid_connect.token.errors.client_assertion_replayed'))
    end

    it 'does not consume the jti when the signature fails' do
      forged = described_class.new(
        client_assertion: build_client_assertion(
          client_id:, audience:, key: OpenSSL::PKey::RSA.new(2048), jti: 'shared-jti',
        ),
        audience:, key_source:
      ).call
      genuine = described_class.new(
        client_assertion: build_client_assertion(client_id:, audience:, jti: 'shared-jti'),
        audience:, key_source:
      ).call

      expect(forged.success?).to eq(false)
      expect(genuine.success?).to eq(true)
    end

    it 'scopes the replay cache to the caller' do
      other_sp = create(:service_provider, :active, certs: ['saml_test_sp'])
      first = described_class.new(
        client_assertion: build_client_assertion(client_id:, audience:, jti: 'same-jti'),
        audience:, key_source:
      ).call
      other = described_class.new(
        client_assertion: build_client_assertion(
          client_id: other_sp.issuer, audience:, jti: 'same-jti',
        ),
        audience:, key_source:
      ).call

      expect(first.success?).to eq(true)
      expect(other.success?).to eq(true)
    end
  end

  context 'with a resource server key source' do
    let(:key_source) { :resource_server }
    let(:audience) { other_endpoint }
    let(:resource_server) { create(:token_exchange_resource_server, certs: ['saml_test_sp']) }
    let(:client_id) { resource_server.identifier }

    it 'authenticates the resource server by identifier with its own certificates' do
      expect(result.success?).to eq(true)
      expect(result.record).to eq(resource_server)
    end

    it 'does not accept a service provider issuer' do
      sp_result = described_class.new(
        client_assertion: build_client_assertion(
          client_id: service_provider.issuer, audience:,
        ),
        audience:, key_source:
      ).call
      expect(sp_result.error_type).to eq(:unknown_client)
    end

    it 'rejects a signature from a key that is not on the resource server' do
      other = described_class.new(
        client_assertion: build_client_assertion(
          client_id:, audience:, key: saml_test_sp2_private_key,
        ),
        audience:, key_source:
      ).call
      expect(other.error_type).to eq(:invalid_signature)
    end
  end
end
