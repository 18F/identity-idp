# frozen_string_literal: true

# Verifies an RFC 9449 DPoP proof: the short-lived JWT a client signs with a key it holds, one per
# HTTP request, so that a token Login.gov issues can be bound to that key. A token bound this way
# is useless to anyone who copies it: every later use needs a fresh proof from the same key.
#
# The response carries the key thumbprint (`extra[:dpop_thumbprint]`), which is what Login.gov
# stores with the artifact it binds and returns to resource servers as `cnf.jkt` (RFC 7800). Every
# failure maps to the RFC 9449 §5 error `invalid_dpop_proof`; the first error message is the failed
# check's symbol, which is also `extra[:dpop_error_type]`. It goes to the client's developer as the
# `error_description`, never to a person, so it is a stable token to look up rather than a sentence.
class DpopProofForm
  include ActiveModel::Model

  PROOF_TYPE = 'dpop+jwt'
  ALLOWED_ALGORITHMS = %w[ES256 RS256].freeze
  REQUIRED_CLAIMS = %w[jti htm htu iat].freeze
  JTI_NAMESPACE = 'dpop:jti'

  # Each check reads what the ones before it confirmed, so none runs once something has failed:
  # ActiveModel evaluates validations, and their conditions, in declaration order. The jti check
  # is last so a rejected proof never consumes a jti.
  validate :validate_proof_present
  validate :validate_decodable, unless: :failed?
  validate :validate_proof_type, unless: :failed?
  validate :validate_algorithm, unless: :failed?
  validate :validate_public_key, unless: :failed?
  validate :validate_key_is_public_only, unless: :failed?
  validate :validate_signature, unless: :failed?
  validate :validate_signed_payload_unchanged, unless: :failed?
  validate :validate_http_method, unless: :failed?
  validate :validate_http_url, unless: :failed?
  validate :validate_issued_at, unless: :failed?
  validate :validate_token_hash, unless: :failed?
  validate :validate_key_binding, unless: :failed?
  validate :validate_jti_unused, unless: :failed?

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

  # Memoized because the jti check consumes the jti: validating twice would reject the proof the
  # form just accepted.
  # @return [FormResponse] success with `extra[:dpop_thumbprint]`, or failure whose first error
  #   message and `extra[:dpop_error_type]` both name the failed check
  def submit
    return @submit if defined?(@submit)

    success = valid?
    @submit = FormResponse.new(
      success:,
      errors:,
      extra: {
        dpop_thumbprint: (thumbprint if success),
        dpop_error_type: errors.first&.options&.dig(:type),
      },
    )
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
    Digest::SHA256.urlsafe_base64digest(access_token.to_s)
  end

  # The URL as `htu` must name it (RFC 9449 §4.3): scheme, host and path, with no query or
  # fragment, after the syntax-based and scheme-based normalization of RFC 3986 §6.2.2 and §6.2.3
  # that RFC 9449 asks servers to apply: scheme and host lowercased, a default port dropped and an
  # empty path read as `/`. Nothing else is normalized, so `/a` and `/a/` are different URLs.
  def self.normalize_url(url)
    uri = URI.parse(url.to_s)
    return nil unless uri.is_a?(URI::HTTP) && uri.host.present?

    port = uri.port == uri.default_port ? '' : ":#{uri.port}"
    path = uri.path.presence || '/'
    "#{uri.scheme.downcase}://#{uri.host.downcase}#{port}#{path}"
  rescue URI::InvalidURIError
    nil
  end

  # Seconds either side of now within which a proof's `iat` is accepted.
  def self.max_age_seconds
    IdentityConfig.store.dpop_proof_max_age_seconds
  end

  private

  attr_reader :proof, :http_method, :http_url, :access_token, :expected_thumbprint

  def validate_proof_present
    reject(:dpop_proof_missing) if proof.blank?
  end

  def validate_decodable
    reject(:dpop_proof_malformed) if header.nil?
  end

  def validate_proof_type
    reject(:dpop_proof_type) unless header['typ'] == PROOF_TYPE
  end

  # Asymmetric only: `none` or a shared-secret MAC would let anyone mint a proof for this key.
  def validate_algorithm
    reject(:dpop_proof_algorithm) unless ALLOWED_ALGORITHMS.include?(header['alg'])
  end

  # The key is self-asserted; what makes it meaningful is that the same key must sign every
  # later proof for a token bound to it.
  def validate_public_key
    reject(:dpop_proof_key) if jwk.nil?
  end

  def validate_key_is_public_only
    reject(:dpop_proof_private_key) if jwk.private?
  end

  def validate_signature
    reject(:dpop_proof_signature) if payload.nil?
  end

  # From here on the payload is authentic: it was signed by the key in the header. The equality
  # check guards against the library returning a payload other than the one read above.
  def validate_signed_payload_unchanged
    reject(:dpop_proof_malformed) unless payload == unverified_payload
  end

  # `htm` and `htu` name the method and URL of *this* request, so a proof captured for one
  # endpoint cannot be replayed at another.
  def validate_http_method
    reject(:dpop_proof_method) unless payload['htm'] == http_method
  end

  def validate_http_url
    htu = payload['htu']
    expected = DpopProofForm.normalize_url(http_url)
    return if htu.is_a?(String) && expected.present? &&
              DpopProofForm.normalize_url(htu) == expected

    reject(:dpop_proof_uri)
  end

  # Bounds how long a captured proof stays useful. No server nonce (RFC 9449 §8) is issued.
  def validate_issued_at
    iat = payload['iat']
    now = Time.zone.now.to_i
    window = DpopProofForm.max_age_seconds
    return if iat.is_a?(Integer) && iat.between?(now - window, now + window)

    reject(:dpop_proof_issued_at)
  end

  # `ath` is required whenever a token accompanies the proof, so the proof cannot be moved to a
  # different token, and must not appear otherwise.
  def validate_token_hash
    ath = payload['ath']
    expected = access_token.blank? ? nil : DpopProofForm.token_hash(access_token)
    reject(:dpop_proof_token_hash) unless ath == expected
  end

  # The thumbprint is the key's identity: it is what gets stored on the token and what a later
  # proof is compared against.
  def validate_key_binding
    return if expected_thumbprint.blank? || thumbprint == expected_thumbprint

    reject(:dpop_key_mismatch)
  end

  # One use per `jti` per key, for as long as a proof with that `jti` could still be accepted.
  # A proof is acceptable while its `iat` is within the window either side of now, so one with a
  # future `iat` at the edge of the window stays acceptable for two windows; the entry lives that
  # long.
  def validate_jti_unused
    first_use = ReplayGuard.first_use?(
      namespace: JTI_NAMESPACE,
      scope: thumbprint,
      value: payload['jti'],
      ttl: DpopProofForm.max_age_seconds * 2,
    )
    reject(:dpop_proof_replayed) unless first_use
  end

  def failed?
    errors.any?
  end

  # The app's convention for forms: the message is the second argument and the machine-readable
  # symbol rides in `type:`, which is where `errors.details` and FormResponse read it from. The
  # message is the symbol itself: the error reaches another program, not a person.
  def reject(error_type)
    errors.add(:proof, error_type.to_s, type: error_type)
  end

  # Read the header without trusting anything yet: it tells us which key and algorithm the client
  # claims, and those claims are what the checks above confirm.
  # @return [Array(Hash, Hash), Array(nil, nil)] header and payload, read without verification
  def unverified
    return @unverified if defined?(@unverified)
    decoded_payload, decoded_header = JWT.decode(proof, nil, false)
    expected_shape = decoded_header.is_a?(Hash) && decoded_payload.is_a?(Hash)
    @unverified = expected_shape ? [decoded_header, decoded_payload] : [nil, nil]
  rescue JWT::DecodeError
    @unverified = [nil, nil]
  end

  def header
    unverified.first
  end

  def unverified_payload
    unverified.last
  end

  def jwk
    return @jwk if defined?(@jwk)
    @jwk = import_public_key(header['jwk'])
  end

  def import_public_key(jwk_params)
    return nil unless jwk_params.is_a?(Hash)
    JWT::JWK.new(jwk_params.deep_symbolize_keys.except(:kid))
  rescue JWT::JWKError, ArgumentError, OpenSSL::PKey::PKeyError, TypeError
    nil
  end

  # The algorithm is pinned to the header value already checked against the allowlist; the
  # library is told not to judge `iat` or `exp`, which are checked here under the proof's rules.
  def payload
    return @payload if defined?(@payload)
    verified, = JWT.decode(
      proof, jwk.verify_key, true,
      algorithm: header['alg'], required_claims: REQUIRED_CLAIMS,
      verify_iat: false, verify_expiration: false
    )
    @payload = verified
  rescue JWT::DecodeError
    @payload = nil
  end

  def thumbprint
    @thumbprint ||= DpopProofForm.thumbprint(jwk)
  end
end
