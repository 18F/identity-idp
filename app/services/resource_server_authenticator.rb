# frozen_string_literal: true

# Authenticates a server-to-server caller of the delegated-access endpoints from its
# `private_key_jwt` client assertion (RFC 7523 §3, hardened per RFC 8725). A confidential service
# provider presents one at token exchange; an agency API presents one when it verifies or revokes
# a token.
#
# The same check serves both kinds of caller, selected by `key_source`:
#
# * `:service_provider` - the `iss`/`sub` claim is a ServiceProvider issuer and the signature is
#   checked against that record's certificates (the keys the service provider already uses for
#   the authorization-code grant).
# * `:resource_server` - the `iss`/`sub` claim is a TokenExchangeResourceServer identifier and the
#   signature is checked against the resource server's own certificates.
#
# What is verified, in order, and why:
#
# 1. The assertion parses and names a registered caller (`iss` == `sub`).
# 2. The signature verifies with RS256 (pinned; the `alg` header is not trusted) under at least
#    one certificate on the record. Every certificate is tried so key rotation does not break
#    callers mid-rollover.
# 3. `aud` names this endpoint's URL (a trailing slash is ignored), so an assertion minted for one
#    endpoint cannot be replayed at another.
# 4. `exp` is present, in the future, and at most five minutes after `iat` (or after "now" when
#    `iat` is omitted); `iat` is not in the future beyond a small clock-skew leeway. Machines call
#    these endpoints thousands of times a day, so a stolen assertion must be worthless quickly.
# 5. `jti` is present and has not been seen from this caller within the assertion lifetime. Seen
#    values are kept in Redis for the maximum lifetime, so a captured assertion cannot be
#    replayed even inside its validity window.
#
# The signature is verified before the replay cache is touched, so an unauthenticated party
# cannot burn a legitimate caller's `jti` values.
class ResourceServerAuthenticator
  include ActionView::Helpers::TranslationHelper

  ISSUED_AT_LEEWAY_SECONDS = 10
  MAX_LIFETIME_SECONDS = 300
  REQUIRED_CLAIMS = %w[iss sub aud exp jti].freeze
  KEY_SOURCES = %i[service_provider resource_server].freeze
  JTI_NAMESPACE = 'client-assertion:jti'

  # @!attribute record
  #   @return [ServiceProvider, TokenExchangeResourceServer, nil] the authenticated caller
  # @!attribute claimed_identifier
  #   @return [String, nil] the `iss` the assertion named, verified or not, for analytics
  # @!attribute error_type
  #   @return [Symbol, nil] machine-readable failure reason, for analytics
  # @!attribute error_message
  #   @return [String, nil] human-readable failure reason, for `error_description`
  Result = Struct.new(
    :record, :claimed_identifier, :error_type, :error_message, keyword_init: true
  ) do
    def success?
      record.present? && error_type.nil?
    end
  end

  # @param client_assertion [String, nil] the `client_assertion` request parameter
  # @param audience [String] absolute URL of the endpoint being called
  # @param key_source [Symbol] `:service_provider` or `:resource_server`
  def initialize(client_assertion:, audience:, key_source:)
    raise ArgumentError, "unknown key_source #{key_source.inspect}" unless
      KEY_SOURCES.include?(key_source)

    @client_assertion = client_assertion
    @audience = audience.to_s.chomp('/')
    @key_source = key_source
  end

  # @return [Result]
  def call
    return failure(:client_assertion_missing) if client_assertion.blank?

    identifier = unverified_issuer
    return failure(:client_assertion_malformed) if identifier.blank?

    record = find_record(identifier)
    return failure(:unknown_client, identifier:) if record.nil?

    payload, decode_error = verify_signature(record, identifier)
    if payload.nil?
      return failure(signature_error_type(decode_error), identifier:, decode_error:)
    end

    return failure(:invalid_aud, identifier:) unless audience_matches?(payload)
    return failure(:invalid_iat, identifier:) unless issued_at_acceptable?(payload)
    return failure(:client_assertion_lifetime, identifier:) unless lifetime_acceptable?(payload)
    unless first_use_of_jti?(identifier, payload)
      return failure(:client_assertion_replayed, identifier:)
    end

    Result.new(record:, claimed_identifier: identifier)
  end

  private

  attr_reader :client_assertion, :audience, :key_source

  # Reads `iss` and `sub` without checking the signature so we know whose keys to verify with.
  # Nothing is trusted from this read except the record lookup that follows.
  def unverified_issuer
    payload, = JWT.decode(client_assertion, nil, false)
    return nil unless payload.is_a?(Hash)
    return nil unless payload['iss'].is_a?(String) && payload['iss'] == payload['sub']
    payload['iss']
  rescue JWT::DecodeError
    nil
  end

  def find_record(identifier)
    case key_source
    when :service_provider then ServiceProvider.find_by(issuer: identifier)
    when :resource_server then TokenExchangeResourceServer.find_by(identifier:)
    end
  end

  # @return [Array(Hash, nil), Array(nil, JWT::DecodeError)] verified payload or the last error
  def verify_signature(record, identifier)
    last_error = nil
    Array(record.ssl_certs).each do |cert|
      payload, = JWT.decode(
        client_assertion, cert.public_key, true,
        algorithm: 'RS256',
        iss: identifier, verify_iss: true,
        sub: identifier, verify_sub: true,
        required_claims: REQUIRED_CLAIMS,
        verify_expiration: true,
        verify_iat: false
      )
      return [payload, nil]
    rescue JWT::DecodeError => e
      last_error = e
      next
    end
    [nil, last_error]
  end

  def audience_matches?(payload)
    Array.wrap(payload['aud']).any? { |aud| aud.to_s.chomp('/') == audience }
  end

  # `iat` is optional under RFC 7523, but when present it may not be in the future.
  def issued_at_acceptable?(payload)
    return true unless payload.key?('iat')
    iat = payload['iat']
    iat.is_a?(Numeric) && (iat.to_i - ISSUED_AT_LEEWAY_SECONDS) <= Time.zone.now.to_i
  end

  # `exp` may be no more than five minutes after `iat` (or after now, when `iat` is absent).
  def lifetime_acceptable?(payload)
    exp = payload['exp']
    return false unless exp.is_a?(Numeric)
    start = payload['iat'].is_a?(Numeric) ? payload['iat'].to_i : Time.zone.now.to_i
    (exp.to_i - start) <= MAX_LIFETIME_SECONDS + ISSUED_AT_LEEWAY_SECONDS
  end

  # Records the `jti` for this caller and reports whether it was new. The entry lives for the
  # maximum assertion lifetime, which is as long as the assertion itself could be accepted.
  def first_use_of_jti?(identifier, payload)
    ReplayGuard.first_use?(
      namespace: JTI_NAMESPACE, scope: identifier, value: payload['jti'],
      ttl: MAX_LIFETIME_SECONDS + ISSUED_AT_LEEWAY_SECONDS
    )
  end

  # Distinguishes the library's reasons for analytics; the message shown to the caller is the
  # library's own, as the authorization-code grant already does.
  def signature_error_type(decode_error)
    case decode_error
    when JWT::ExpiredSignature then :client_assertion_expired
    when JWT::MissingRequiredClaim then :client_assertion_missing_claim
    else :invalid_signature
    end
  end

  def failure(error_type, identifier: nil, decode_error: nil)
    Result.new(
      claimed_identifier: identifier,
      error_type:,
      error_message: message_for(error_type, decode_error),
    )
  end

  def message_for(error_type, decode_error)
    case error_type
    when :invalid_signature, :client_assertion_expired, :client_assertion_missing_claim
      decode_error&.message || t('openid_connect.token.errors.invalid_signature')
    when :invalid_aud then t('openid_connect.token.errors.invalid_aud', url: audience)
    when :invalid_iat then t('openid_connect.token.errors.invalid_iat')
    when :client_assertion_missing then t('openid_connect.token.errors.client_assertion_missing')
    when :client_assertion_malformed
      t('openid_connect.token.errors.client_assertion_malformed')
    when :unknown_client then t('openid_connect.token.errors.unknown_client')
    when :client_assertion_lifetime
      t('openid_connect.token.errors.client_assertion_lifetime')
    when :client_assertion_replayed
      t('openid_connect.token.errors.client_assertion_replayed')
    end
  end
end
