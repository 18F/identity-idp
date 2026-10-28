# frozen_string_literal: true

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
    DpopProofForm.thumbprint(key)
  end

  # @param url [String] the request URL the proof is for
  # @param method [String] the HTTP method
  # @param key [OpenSSL::PKey::PKey] signing key
  # @param access_token [String, nil] adds `ath` when a token accompanies the proof
  # @param header [Hash] header overrides; `alg:` selects the algorithm (default ES256)
  # @param claims [Hash] overrides or additions; pass `claim: nil` to omit a default claim
  def build_dpop_proof(http_url:, http_method: 'POST', key: dpop_key, access_token: nil, header: {},
                       **claims)
    payload = {
      jti: SecureRandom.urlsafe_base64(16),
      htm: http_method,
      htu: http_url,
      iat: Time.zone.now.to_i,
    }
    payload[:ath] = DpopProofForm.token_hash(access_token) if access_token
    payload = payload.merge(claims).compact
    headers = { typ: 'dpop+jwt', jwk: dpop_jwk(key) }.merge(header).compact
    JWT.encode(payload, key, headers.delete(:alg) || 'ES256', headers)
  end
end
