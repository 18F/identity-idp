# frozen_string_literal: true

# Verifies an RFC 9449 DPoP proof: the short-lived JWT a client signs with a key it holds, one per
# HTTP request, so that a token Login.gov issues can be bound to that key. A token bound this way
# is useless to anyone who copies it: every later use needs a fresh proof from the same key.
#
# Checks, in the order RFC 9449 §4.3 lists them, and why each exists:
#
# 1. The proof parses, its `typ` header is `dpop+jwt`, and `alg` is an asymmetric algorithm
#    Login.gov accepts (ES256 or RS256; never `none`, never a shared-secret MAC).
# 2. The `jwk` header is a public key with no private members, and the signature verifies under
#    it. The key is self-asserted; what makes it meaningful is that the same key must sign every
#    later proof.
# 3. `htm` and `htu` name the method and URL of *this* request, so a proof captured for one
#    endpoint cannot be replayed at another. The URL is compared without query or fragment, with
#    scheme and host lowercased and default ports dropped.
# 4. `iat` is within the acceptance window (`dpop_proof_max_age_seconds` either side of now),
#    which bounds how long a captured proof stays useful. No server nonce (§8) is issued.
# 5. When a token is being presented alongside the proof, `ath` is the base64url SHA-256 of that
#    token, so the proof cannot be moved to a different token. Without a token, `ath` must be
#    absent.
# 6. When the token is already bound, the proof key's RFC 7638 thumbprint equals the stored one.
# 7. `jti` has not been seen before. Seen values are kept in Redis for as long as a proof with
#    that `jti` could still be accepted, and only after the signature verified, so an attacker
#    cannot burn a legitimate client's values.
#
# The result carries the key thumbprint, which is what Login.gov stores on the token (`dpop_jkt`)
# and returns to resource servers as `cnf.jkt` (RFC 7800). Every failure maps to the RFC 9449 §5
# error `invalid_dpop_proof`; the result's message is the `error_description`.
class DpopProofVerifier
  include ActionView::Helpers::TranslationHelper

  PROOF_TYPE = 'dpop+jwt'
  ALLOWED_ALGORITHMS = %w[ES256 RS256].freeze
  REQUIRED_CLAIMS = %w[jti htm htu iat].freeze
  JTI_KEY_PREFIX = 'dpop:jti:'

  # @!attribute thumbprint
  #   @return [String, nil] RFC 7638 thumbprint of the proof key, on success
  # @!attribute error_type
  #   @return [Symbol, nil] machine-readable failure reason, for analytics
  # @!attribute error_message
  #   @return [String, nil] human-readable failure reason, for `error_description`
  Result = Struct.new(:thumbprint, :error_type, :error_message, keyword_init: true) do
    def success?
      thumbprint.present? && error_type.nil?
    end
  end

  # @param proof [String, nil] the `DPoP` request header value
  # @param http_method [String] method of the request the proof accompanies
  # @param http_url [String] absolute URL of that request
  # @param access_token [String, nil] the token presented with the proof, when there is one, so
  #   `ath` can be checked
  # @param expected_thumbprint [String, nil] the thumbprint the token is already bound to, if any
  def initialize(proof:, http_method:, http_url:, access_token: nil, expected_thumbprint: nil)
    @proof = proof
    @http_method = http_method.to_s.upcase
    @http_url = http_url
    @access_token = access_token
    @expected_thumbprint = expected_thumbprint
  end

  # @return [Result]
  def call
    return failure(:dpop_proof_missing) if proof.blank?

    # Read the header without trusting anything yet: it tells us which key and algorithm the
    # client claims, and those claims are what the checks below confirm.
    header, unverified_payload = decode_unverified
    return failure(:dpop_proof_malformed) if header.nil?
    return failure(:dpop_proof_type) unless header['typ'] == PROOF_TYPE
    return failure(:dpop_proof_algorithm) unless ALLOWED_ALGORITHMS.include?(header['alg'])

    jwk = import_public_key(header['jwk'])
    return failure(:dpop_proof_key) if jwk.nil?
    return failure(:dpop_proof_private_key) if jwk.private?

    # From here on the payload is authentic: it was signed by the key in the header. The equality
    # check guards against the library returning a payload other than the one read above.
    payload = verify_signature(jwk, header['alg'])
    return failure(:dpop_proof_signature) if payload.nil?
    return failure(:dpop_proof_malformed) unless payload == unverified_payload

    return failure(:dpop_proof_method) unless payload['htm'] == http_method
    return failure(:dpop_proof_uri) unless uri_matches?(payload['htu'])
    return failure(:dpop_proof_issued_at) unless issued_at_acceptable?(payload['iat'])
    return failure(:dpop_proof_token_hash) unless token_hash_matches?(payload['ath'])

    # The thumbprint is the key's identity: it is what gets stored on the token and what a later
    # proof is compared against. The jti check is last so a rejected proof never consumes a jti.
    thumbprint = self.class.thumbprint(jwk)
    if expected_thumbprint.present? && thumbprint != expected_thumbprint
      return failure(:dpop_key_mismatch)
    end
    return failure(:dpop_proof_replayed) unless first_use_of_jti?(thumbprint, payload['jti'])

    Result.new(thumbprint:)
  end

  # RFC 7638 thumbprint of a key: base64url of the SHA-256 over the key's required public members
  # in lexicographic order, which is how the JWK library computes it.
  # @param key [JWT::JWK::KeyBase, OpenSSL::PKey::PKey, Hash] a JWK or something one can be built
  #   from
  # @return [String]
  def self.thumbprint(key)
    jwk = key.is_a?(JWT::JWK::KeyBase) ? key : JWT::JWK.new(key)
    JWT::JWK::Thumbprint.new(jwk).generate
  end

  # RFC 9449 §4.2 `ath`: base64url, unpadded, of the SHA-256 of the token exactly as presented.
  def self.token_hash(access_token)
    Base64.urlsafe_encode64(Digest::SHA256.digest(access_token.to_s), padding: false)
  end

  # The URL as `htu` must name it (RFC 9449 §4.3): scheme, host and path, with no query or
  # fragment, scheme and host lowercased, default ports dropped and a trailing slash ignored.
  def self.normalize_url(url)
    uri = URI.parse(url.to_s)
    return nil unless uri.is_a?(URI::HTTP) && uri.host.present?

    port = uri.port == uri.default_port ? '' : ":#{uri.port}"
    path = uri.path.presence || '/'
    "#{uri.scheme.downcase}://#{uri.host.downcase}#{port}#{path.chomp('/')}"
  rescue URI::InvalidURIError
    nil
  end

  # Seconds either side of now within which a proof's `iat` is accepted.
  def self.max_age_seconds
    IdentityConfig.store.dpop_proof_max_age_seconds
  end

  private

  attr_reader :proof, :http_method, :http_url, :access_token, :expected_thumbprint

  # @return [Array(Hash, Hash), Array(nil, nil)] header and payload, read without verification
  def decode_unverified
    payload, header = JWT.decode(proof, nil, false)
    return [nil, nil] unless header.is_a?(Hash) && payload.is_a?(Hash)
    [header, payload]
  rescue JWT::DecodeError
    [nil, nil]
  end

  def import_public_key(jwk_params)
    return nil unless jwk_params.is_a?(Hash)
    JWT::JWK.new(jwk_params.deep_symbolize_keys.except(:kid))
  rescue JWT::JWKError, ArgumentError, OpenSSL::PKey::PKeyError, TypeError
    nil
  end

  # The algorithm is pinned to the header value already checked against the allowlist; the
  # library is told not to judge `iat` or `exp`, which are checked here under the proof's rules.
  def verify_signature(jwk, algorithm)
    payload, = JWT.decode(
      proof, jwk.verify_key, true,
      algorithm:, required_claims: REQUIRED_CLAIMS, verify_iat: false, verify_expiration: false
    )
    payload
  rescue JWT::DecodeError
    nil
  end

  def uri_matches?(htu)
    return false unless htu.is_a?(String)
    expected = self.class.normalize_url(http_url)
    expected.present? && self.class.normalize_url(htu) == expected
  end

  def issued_at_acceptable?(iat)
    return false unless iat.is_a?(Integer)
    now = Time.zone.now.to_i
    window = self.class.max_age_seconds
    iat.between?(now - window, now + window)
  end

  # `ath` is required whenever a token accompanies the proof and must not appear otherwise.
  def token_hash_matches?(ath)
    return ath.nil? if access_token.blank?
    ath == self.class.token_hash(access_token)
  end

  # One use per `jti` per key, for as long as a proof with that `jti` could still be accepted.
  # A proof is acceptable while its `iat` is within the window either side of now, so one with a
  # future `iat` at the edge of the window stays acceptable for two windows; the entry lives that
  # long.
  def first_use_of_jti?(thumbprint, jti)
    return false unless jti.is_a?(String) && jti.present?

    key = JTI_KEY_PREFIX + Digest::SHA256.hexdigest("#{thumbprint}\n#{jti}")
    ttl = self.class.max_age_seconds * 2
    REDIS_POOL.with { |client| client.set(key, '1', nx: true, ex: ttl) } ? true : false
  end

  def failure(error_type)
    Result.new(error_type:, error_message: message_for(error_type))
  end

  # The `error_description` for `invalid_dpop_proof`. Three cases get their own wording because
  # the client's fix differs: send a proof, sign with the bound key, or use a fresh jti. Every
  # other failure gets the one description listing what a valid proof must satisfy, so the
  # response does not help an attacker tune a forged proof check by check.
  def message_for(error_type)
    case error_type
    when :dpop_proof_missing then t('openid_connect.token.errors.dpop_proof_required')
    when :dpop_key_mismatch then t('openid_connect.token.errors.dpop_key_mismatch')
    when :dpop_proof_replayed then t('openid_connect.token.errors.dpop_proof_replayed')
    else t('openid_connect.token.errors.dpop_proof_invalid')
    end
  end
end
