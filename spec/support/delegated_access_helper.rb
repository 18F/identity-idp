# Builders for the credentials delegated-access specs present to Login.gov: RFC 7523 client
# assertions signed with the fixture keys under keys/, and RFC 9449 DPoP proofs.
module DelegatedAccessHelper
  # In a request spec there is no controller instance until the request has run, so the
  # controller-spec `stub_analytics` has nothing to stub; stub every controller instead.
  def stub_request_analytics
    @analytics = FakeAnalytics.new
    allow_any_instance_of(ApplicationController).to receive(:analytics).and_return(@analytics)
    @analytics
  end

  # Private key matching certs/sp/saml_test_sp.crt, the default certificate on service provider
  # and resource server factories.
  def saml_test_sp_private_key
    OpenSSL::PKey::RSA.new(Rails.root.join('keys', 'saml_test_sp.key').read)
  end

  def saml_test_sp2_private_key
    OpenSSL::PKey::RSA.new(Rails.root.join('keys', 'saml_test_sp2.key').read)
  end

  # @param client_id [String] the caller's identifier (SP issuer or resource server identifier)
  # @param audience [String] the endpoint URL the assertion is for
  # @param key [OpenSSL::PKey::RSA] signing key
  # @param claims [Hash] overrides or additions; pass `claim: nil` to omit a default claim
  def build_client_assertion(client_id:, audience:, key: saml_test_sp_private_key, **claims)
    now = Time.zone.now.to_i
    payload = {
      iss: client_id,
      sub: client_id,
      aud: audience,
      jti: SecureRandom.hex(16),
      iat: now,
      exp: now + 60,
    }.merge(claims).compact
    JWT.encode(payload, key, 'RS256')
  end
end

# Builders for RFC 9449 DPoP proofs, so specs can exercise key-bound tokens.
module DpopHelper
  # One P-256 key per example, the key a browser-based client would generate for a sign-in.
  def dpop_key
    @dpop_key ||= OpenSSL::PKey::EC.generate('prime256v1')
  end

  def dpop_jwk(key = dpop_key)
    JWT::JWK.new(key).export
  end

  def dpop_thumbprint(key = dpop_key)
    DpopProofVerifier.thumbprint(key)
  end

  # @param url [String] the request URL the proof is for
  # @param method [String] the HTTP method
  # @param key [OpenSSL::PKey::PKey] signing key
  # @param access_token [String, nil] adds `ath` when a token accompanies the proof
  # @param header [Hash] header overrides; `alg:` selects the algorithm (default ES256)
  # @param claims [Hash] overrides or additions; pass `claim: nil` to omit a default claim
  def build_dpop_proof(url:, method: 'POST', key: dpop_key, access_token: nil, header: {},
                       **claims)
    payload = {
      jti: SecureRandom.urlsafe_base64(16),
      htm: method,
      htu: url,
      iat: Time.zone.now.to_i,
    }
    payload[:ath] = DpopProofVerifier.token_hash(access_token) if access_token
    payload = payload.merge(claims).compact
    headers = { typ: 'dpop+jwt', jwk: dpop_jwk(key) }.merge(header).compact
    JWT.encode(payload, key, headers.delete(:alg) || 'ES256', headers)
  end
end
