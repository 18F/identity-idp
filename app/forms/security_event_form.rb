class SecurityEventForm
  include Rails.application.routes.url_helpers
  include ActiveModel::Model

  attr_reader :err

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
        jti: jwt_payload['jti'],
        issuer: service_provider.issuer,
      )
    else
      # TODO: calculate err code
      # @err = 'setData'
    end

    FormResponse.new(success: success, errors: errors.messages, extra: extra_analytics_attributes)
  end

  private

  attr_reader :body

  def jwt_payload
    return @jwt_payload if defined?(@jwt_payload)
    payload, _headers = JWT.decode(body, nil, false, algorithm: 'RS256')
    @jwt_payload = payload
  rescue JWT::DecodeError => err
    @err = 'jwtParse'
    errors.add(:jwt, err.message)
    @jwt_payload = {}
  end

  def validate_jwt_signature
    return false if !service_provider
    JWT.decode(body, service_provider.ssl_cert.public_key, true, algorithm: 'RS256')
  rescue JWT::DecodeError => err
    @err = 'jws'
    errors.add(:jwt, err.message)
    false
  end

  def validate_iss
    if !service_provider.present?
      errors.add(:iss, 'invalid issuer')
    end
  end

  def validate_aud
    if jwt_payload['aud'] != api_security_events_url
      errors.add(:aud, "invalid aud claim, expected #{api_security_events_url}")
    end
  end

  def validate_event_type
    if event_type.blank?
      errors.add(:event_type, 'missing event')
    elsif event_type != SecurityEvent::CREDENTIAL_CHANGE_REQUIRED
      errors.add(:event_type, "unsupported event type #{event_type}")
    end
  end

  def validate_subject_type
    if subject_type != 'iss_sub'
      errors.add(:subject_type, 'subject_type must be iss_sub')
    end
  end

  def validate_sub
    if user.blank?
      errors.add(:sub, 'invalid sub claim')
    end
  end


  def service_provider
    return @service_provider if defined?(@service_provider)
    @service_provider = ServiceProvider.find_by(issuer: jwt_payload['iss'])
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

  # TODO
  def extra_analytics_attributes
    {}
  end
end

<<-EOS
  json      | Invalid JSON object.                                  |
  jwtParse  | Invalid or unparsable JWT or JSON structure.          |
  jwtHdr    | In invalid JWT header was detected.                   |
  jwtCrypto | Unable to parse due to unsupported algorithm.         |
  jws       | Signature was not validated.                          |
  jwe       | Unable to decrypt JWE encoded data.                   |
  jwtAud    | Invalid audience value.                               |
  jwtIss    | Issuer not recognized.                                |
  setType   | An unexpected Event type was received.                |
  setParse  | Invalid structure was encountered such as an          |
            | inability to parse or an incomplete set of Event      |
            | claims.                                               |
  setData   | SET event claims incomplete or invalid.               |
  dup       | A duplicate SET was received and has been ignored.    |
EOS