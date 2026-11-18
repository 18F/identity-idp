# frozen_string_literal: true

class OpenidConnectClientAssertionValidator
  ISSUED_AT_LEEWAY_SECONDS = 10
  JTI_NAMESPACE = 'client-assertion:jti'
  MISSING_EXP_MESSAGE = 'exp is required and must be an integer or floating point Unix timestamp'
  INVALID_EXP_MESSAGE = 'exp may be no more than %d seconds after iat, ' \
                        'or after the time of the request when iat is absent'
  MISSING_JTI_MESSAGE = 'jti is required and must be a string that is unique to this assertion'
  REPLAYED_JTI_MESSAGE = 'jti has already been used; each client assertion must carry a new jti'

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

  def validate_exp(payload)
    exp = payload['exp']
    unless exp.is_a?(Numeric)
      add_error(MISSING_EXP_MESSAGE, :missing_exp)
      return
    end

    issued_at = payload['iat'].is_a?(Numeric) ? payload['iat'].to_i : Time.zone.now.to_i
    max_lifetime = IdentityConfig.store.client_assertion_max_lifetime_seconds
    return if exp.to_i - issued_at <= max_lifetime

    add_error(format(INVALID_EXP_MESSAGE, max_lifetime), :invalid_exp)
  end

  # `jti`s can only be used once, to prevent replays
  def validate_jti_unused(payload)
    jti = payload['jti']
    unless jti.is_a?(String) && jti.present?
      add_error(MISSING_JTI_MESSAGE, :missing_jti)
      return
    end

    first_use = ReplayGuard.first_use?(
      namespace: JTI_NAMESPACE,
      scope: client_id,
      value: jti,
      ttl: [payload['exp'].to_i - Time.zone.now.to_i, 1].max,
    )
    return if first_use

    add_error(REPLAYED_JTI_MESSAGE, :replayed_jti)
  end

  def add_error(message, type)
    @errors << ValidationError.new(
      attribute: :client_assertion,
      message:,
      type:,
    )
  end
end
