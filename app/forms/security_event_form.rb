# rubocop:disable Metrics/ClassLength
# Handles SET events (Security Event Tokens)
class SecurityEventForm
  include Rails.application.routes.url_helpers
  include ActiveModel::Model

  # From https://tools.ietf.org/html/draft-ietf-secevent-http-push-00#section-2.3
  module ErrorCodes
    JWS = 'jws'.freeze
    JWT_AUD = 'jwtAud'.freeze
    JWT_PARSE = 'jwtParse'.freeze
    SET_DATA = 'setData'.freeze
    SET_TYPE = 'setType'.freeze
  end

  validate :validate_iss
  validate :validate_aud
  validate :validate_event_type
  validate :validate_subject_type
  validate :validate_sub
  validate :validate_jwt_signature

  def initialize(body:)
    @body = body
  end

  def submit
    success = valid?

    if success
      SecurityEvent.create(
        user: user,
        event_type: event_type,
        jti: jti,
        issuer: service_provider.issuer,
      )
    end

    FormResponse.new(success: success, errors: errors.messages, extra: extra_analytics_attributes)
  end

  def error_code
    return if valid?

    @error_code ||= ErrorCodes::SET_DATA
  end

  def description
    return if valid?

    errors.full_messages.join(', ')
  end

  private

  attr_reader :body

  def jwt_payload
    return @jwt_payload if defined?(@jwt_payload)

    payload, _headers = JWT.decode(body, nil, false, algorithm: 'RS256')
    @jwt_payload = payload
  rescue JWT::DecodeError => err
    @error_code = ErrorCodes::JWT_PARSE
    errors.add(:jwt, err.message)
    @jwt_payload = {}
  end

  def validate_jwt_signature
    return false unless service_provider
    JWT.decode(body, service_provider.ssl_cert.public_key, true, algorithm: 'RS256')
  rescue JWT::DecodeError => err
    @error_code = ErrorCodes::JWS
    errors.add(:jwt, err.message)
    false
  end

  def validate_iss
    errors.add(:iss, 'invalid issuer') if service_provider.blank?
  end

  def validate_aud
    return if jwt_payload.blank?
    return if jwt_payload['aud'] == api_security_events_url

    errors.add(:aud, "invalid aud claim, expected #{api_security_events_url}")
    @error_code = ErrorCodes::JWT_AUD
  end

  def validate_event_type
    if event_type.blank?
      errors.add(:event_type, 'missing event')
    elsif event_type != SecurityEvent::CREDENTIAL_CHANGE_REQUIRED
      errors.add(:event_type, "unsupported event type #{event_type}")
      @error_code = ErrorCodes::SET_TYPE
    end
  end

  def validate_subject_type
    return if subject_type == 'iss_sub'

    errors.add(:subject_type, 'subject_type must be iss_sub')
  end

  def validate_sub
    errors.add(:sub, 'invalid sub claim') if user.blank?
  end

  def client_id
    jwt_payload['iss']
  end

  def jti
    jwt_payload['jti']
  end

  def service_provider
    return @service_provider if defined?(@service_provider)

    @service_provider = ServiceProvider.find_by(issuer: client_id)
  end

  def event
    jwt_payload.dig('events', event_type) || {}
  end

  def event_type
    return nil if jwt_payload['events'].blank?

    if jwt_payload['events'].key?(SecurityEvent::CREDENTIAL_CHANGE_REQUIRED)
      SecurityEvent::CREDENTIAL_CHANGE_REQUIRED
    else
      jwt_payload['events'].keys.first
    end
  end

  def subject_type
    event.dig('subject', 'subject_type')
  end

  def identity
    return if event.blank? || !service_provider
    return @identity if defined?(@identity)

    @identity = Identity.find_by(
      uuid: event.dig('subject', 'sub'),
      service_provider: service_provider.issuer,
    )
  end

  def user
    identity&.user
  end

  def extra_analytics_attributes
    {
      client_id: client_id,
      error_code: error_code,
      jti: jti,
      user_id: user&.uuid,
    }
  end
end
# rubocop:enable Metrics/ClassLength
