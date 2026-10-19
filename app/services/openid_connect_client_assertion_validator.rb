# frozen_string_literal: true

class OpenidConnectClientAssertionValidator
  ISSUED_AT_LEEWAY_SECONDS = 10

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

  def add_error(message, type)
    @errors << ValidationError.new(
      attribute: :client_assertion,
      message:,
      type:,
    )
  end
end
