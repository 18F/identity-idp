# frozen_string_literal: true

# Verifies the `client_assertion` a service provider presents to authenticate itself with a key it
# registered (RFC 7523 section 3): a JWT signed by one of its certificates, issued by and about the
# client (`iss` and `sub`), addressed to the endpoint receiving it (`aud`), not issued in the future
# (`iat`), expiring soon (`exp`) and carrying an identifier used exactly once (`jti`). An assertion
# passes only when every check passes; the replay record is written last so a refused assertion
# never consumes its identifier.
class OpenidConnectClientAssertionValidator
  ISSUED_AT_LEEWAY_SECONDS = 10
  JTI_NAMESPACE = 'client-assertion:jti'

  ValidationError = Struct.new(:attribute, :message, :type, keyword_init: true)

  attr_reader :client_assertion, :client_id, :service_provider, :audience_url

  def initialize(client_assertion:, client_id:, service_provider:, audience_url:)
    @client_assertion = client_assertion
    @client_id = client_id
    @service_provider = service_provider
    @audience_url = audience_url
  end

  def errors
    return [] if valid?

    @errors
  end

  # Memoized: the replay check records the assertion's `jti`, so validating twice would refuse the
  # assertion that was just accepted.
  def valid?
    return @valid if defined?(@valid)

    @errors = []
    validate_assertion
    @valid = @errors.blank?
  end

  private

  def validate_assertion
    payload, _headers, err = nil

    matching_cert = service_provider&.ssl_certs&.find do |ssl_cert|
      err = nil
      payload, _headers = JWT.decode(
        client_assertion, ssl_cert.public_key, true,
        algorithm: 'RS256', iss: client_id,
        verify_iss: true, sub: client_id,
        verify_sub: true
      )
    rescue JWT::DecodeError => err
      next
    end

    if matching_cert && payload
      validate_aud_claim(payload)
      validate_iat(payload)
      validate_exp(payload)
      validate_jti_unused(payload) if @errors.blank?
    else
      add_error(
        err&.message || I18n.t('openid_connect.token.errors.invalid_signature'),
        :invalid_signature,
      )
    end
  end

  def validate_aud_claim(payload)
    aud_as_array = Array.wrap(payload['aud'])
    aud_as_array.map! { |aud| aud.to_s.chomp('/') }
    return if aud_as_array.include?(audience_url)

    add_error(
      I18n.t('openid_connect.token.errors.invalid_aud', url: audience_url),
      :invalid_aud,
    )
  end

  def validate_iat(payload)
    return unless payload.key?('iat')
    iat = payload['iat']
    return if iat.is_a?(Numeric) && (iat.to_i - ISSUED_AT_LEEWAY_SECONDS) < Time.zone.now.to_i

    add_error(I18n.t('openid_connect.token.errors.invalid_iat'), :invalid_iat)
  end

  # RFC 7523 section 3 requires `exp`. The JWT library enforces `exp` only when the claim is present
  # (an expired assertion was already refused above), so its presence is checked here, together with
  # the lifetime it grants: the time from `iat` to `exp`, or from now to `exp` when the assertion
  # has no `iat`, may not exceed `client_assertion_max_lifetime_seconds`. An assertion without `exp`
  # would otherwise be a permanent credential, and one with a distant `exp` stays useful to anyone
  # who captures it for as long as it says.
  def validate_exp(payload)
    exp = payload['exp']
    unless exp.is_a?(Numeric)
      add_error(I18n.t('openid_connect.token.errors.missing_exp'), :missing_exp)
      return
    end

    issued_at = payload['iat'].is_a?(Numeric) ? payload['iat'].to_i : Time.zone.now.to_i
    max_lifetime = IdentityConfig.store.client_assertion_max_lifetime_seconds
    return if exp.to_i - issued_at <= max_lifetime

    add_error(
      I18n.t('openid_connect.token.errors.invalid_exp', seconds: max_lifetime),
      :invalid_exp,
    )
  end

  # Each assertion is accepted once (RFC 7523 section 3): the `jti` is recorded under the client
  # that presented it, so one client cannot exhaust another's identifiers, for as long as the
  # assertion itself remains valid, which is exactly how long a captured copy could still be
  # accepted. The claim is optional in the RFC and required here, because without it a captured
  # assertion is replayable for its whole lifetime; every client library in use sends one.
  def validate_jti_unused(payload)
    jti = payload['jti']
    unless jti.is_a?(String) && jti.present?
      add_error(I18n.t('openid_connect.token.errors.missing_jti'), :missing_jti)
      return
    end

    first_use = ReplayGuard.first_use?(
      namespace: JTI_NAMESPACE,
      scope: client_id,
      value: jti,
      ttl: [payload['exp'].to_i - Time.zone.now.to_i, 1].max,
    )
    return if first_use

    add_error(I18n.t('openid_connect.token.errors.replayed_jti'), :replayed_jti)
  end

  def add_error(message, type)
    @errors << ValidationError.new(
      attribute: :client_assertion,
      message:,
      type:,
    )
  end
end
