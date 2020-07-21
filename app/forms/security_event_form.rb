class SecurityEventForm
  include Rails.application.routes.url_helpers
  include ActiveModel::Model

  attr_reader :err

  validates :service_provider, presence: true
  validates :user, presence: true

  validates_inclusion_of :subject_type, in: %w[iss_sub]
  validates_inclusion_of :aud, in: :root_url
  validates_inclusion_of :event_type, in: [
    SecurityEvent::CREDENTIAL_CHANGE_REQUIRED,
  ]

  validate :validate_jwt_with_signature, if: :service_provider

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
    elsif !@err
      @err = 'setData'
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

  def validate_jwt_with_signature
    JWT.decode(body, service_provider.ssl_cert.public_key, true, algorithm: 'RS256')
  rescue JWT::DecodeError => err
    @err = 'jws'
    errors.add(:jwt, err.message)
    false
  end

  def aud
    jwt_payload['aud']
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
    return if event.blank?
    return @identity if defined?(@identity)
    @identity = Identity.find_by(uuid: event.dig('subject', 'sub'))
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