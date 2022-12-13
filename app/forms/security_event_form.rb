# Handles SET events (Security Event Tokens)
class SecurityEventForm
  include ActionView::Helpers::TranslationHelper
  include ActiveModel::Model
  include Rails.application.routes.url_helpers

  # From https://tools.ietf.org/html/draft-ietf-secevent-http-push-00#section-2.3
  module ErrorCodes
    DUP = 'dup'.freeze
    JWS = 'jws'.freeze
    JWT_AUD = 'jwtAud'.freeze
    JWT_CRYPTO = 'jwtCrypto'.freeze
    JWT_HDR = 'jwtHdr'.freeze
    JWT_PARSE = 'jwtParse'.freeze
    SET_DATA = 'setData'.freeze
    SET_TYPE = 'setType'.freeze
  end

  validate :validate_iss
  validate :validate_aud
  validate :validate_event_type
  validate :validate_subject_type
  validate :validate_sub
  validate :validate_typ
  validate :validate_exp
  validate :validate_jti
  validate :validate_jwt

  def initialize(body:)
    @body = body
    @jwt_payload, @jwt_headers = parse_jwt
  end

  def submit
    success = valid?

    if success
      SecurityEvent.create!(
        event_type: event_type,
        issuer: service_provider.issuer,
        jti: jti,
        user: user,
        occurred_at: occurred_at,
      )

      if event_type == SecurityEvent::AUTHORIZATION_FRAUD_DETECTED
        ResetUserPassword.new(user: user).call
      end
    end

    FormResponse.new(success: success, errors: errors, extra: extra_analytics_attributes)
  end

  def error_code
    return if valid?

    @error_code ||= ErrorCodes::SET_DATA
  end

  def description
    return if valid?

    errors.full_messages.join(', ')
  end

  def url_options
    {}
  end

  private

  attr_reader :body, :jwt_payload, :jwt_headers

  # @return [Array(Hash, Hash)] parses JWT into [payload, headers]
  def parse_jwt
    JWT.decode(body, nil, false, algorithm: 'RS256', leeway: Float::INFINITY)
  rescue JWT::DecodeError
    @error_code = ErrorCodes::JWT_PARSE
    [{}, {}]
  end

  def check_jwt_parse_error
    return false if @error_code != ErrorCodes::JWT_PARSE

    errors.add(
      :jwt,
      t('risc.security_event.errors.jwt_could_not_parse'),
      type: :jwt_could_not_parse,
    )
    true
  end

  def check_public_key_error(public_key)
    return false if public_key.present?

    errors.add(:jwt, t('risc.security_event.errors.no_public_key'), type: :no_public_key)
    @error_code = ErrorCodes::JWS
    true
  end

  def validate_jwt
    return if check_jwt_parse_error

    error_code = nil
    error_message = nil
    error_reason = nil

    matching_public_key = service_provider&.ssl_certs&.find do |ssl_cert|
      error_code = nil
      error_message = nil
      error_reason = nil
      JWT.decode(body, ssl_cert.public_key, true, algorithm: 'RS256', leeway: Float::INFINITY)
    rescue JWT::IncorrectAlgorithm
      error_code = ErrorCodes::JWT_CRYPTO
      error_message = t('risc.security_event.errors.alg_unsupported', expected_alg: 'RS256')
      error_reason = :incorrect_algorithm
      nil
    rescue JWT::VerificationError => err
      error_code = ErrorCodes::JWS
      error_message = err.message
      error_reason = :verification_failed
      nil
    end

    if error_code && error_message && error_reason
      @error_code = error_code
      errors.add(:jwt, error_message, type: error_reason)
    else
      check_public_key_error(matching_public_key)
    end
  end

  def validate_jti
    if jti.blank?
      errors.add(:jti, t('risc.security_event.errors.jti_required'), type: :jti_required)
      return
    end

    return if !user || !service_provider

    return unless record_already_exists?

    errors.add(:jti, t('risc.security_event.errors.jti_not_unique'), type: :jti_not_unique)
    @error_code = ErrorCodes::DUP
  end

  # Memoize this because validations get reset every time valid? is called
  def record_already_exists?
    return @record_already_exists if defined?(@record_already_exists)

    @record_already_exists = SecurityEvent.exists?(
      issuer: service_provider.issuer,
      jti: jti,
      user_id: user.id,
    )
  end

  def validate_iss
    errors.add(:iss, 'invalid issuer', type: :invalid_issuer) if service_provider.blank?
  end

  def validate_aud
    return if jwt_payload.blank?
    return if jwt_payload['aud'] == api_risc_security_events_url

    errors.add(
      :aud,
      t('risc.security_event.errors.aud_invalid', url: api_risc_security_events_url),
      type: :aud_invalid,
    )
    @error_code = ErrorCodes::JWT_AUD
  end

  def validate_event_type
    if event_type.blank?
      errors.add(
        :event_type,
        t('risc.security_event.errors.event_type_missing'),
        type: :event_type_missing,
      )
    elsif !SecurityEvent::EVENT_TYPES.include?(event_type)
      errors.add(
        :event_type,
        t('risc.security_event.errors.event_type_unsupported', event_type: event_type),
        type: :event_type_unsupported,
      )
      @error_code = ErrorCodes::SET_TYPE
    end
  end

  def validate_subject_type
    return if subject_type == 'iss-sub'

    errors.add(
      :subject_type,
      t('risc.security_event.errors.subject_type_unsupported', expected_subject_type: 'iss-sub'),
      type: :subject_type_unsupported,
    )
  end

  def validate_sub
    if jwt_payload['sub'].present?
      errors.add(
        :sub,
        t('risc.security_event.errors.sub_unsupported'),
        type: :sub_unsupported,
      )
    end
    if user.blank?
      errors.add(
        :sub,
        t('risc.security_event.errors.sub_not_found'),
        type: :sub_not_found,
      )
    end
  end

  def validate_typ
    return if jwt_headers.blank?
    return if jwt_headers['typ'] == 'secevent+jwt'

    errors.add(
      :typ,
      t('risc.security_event.errors.typ_error', expected_typ: 'secevent+jwt'),
      type: :typ_error,
    )
    @error_code = ErrorCodes::JWT_HDR
  end

  def validate_exp
    return if jwt_payload['exp'].blank?

    errors.add(:exp, t('risc.security_event.errors.exp_present'), type: :exp_present)
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

    matching_event_types = jwt_payload['events'].keys & SecurityEvent::EVENT_TYPES
    if matching_event_types.present?
      matching_event_types.first
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

    @identity = if service_provider.agency_id
                  identity_from_agency_identity
                else
                  identity_from_identity
                end
  end

  def identity_from_agency_identity
    AgencyIdentity.find_by(
      uuid: event.dig('subject', 'sub'),
      agency_id: service_provider.agency_id,
    )
  end

  def identity_from_identity
    ServiceProviderIdentity.find_by(
      uuid: event.dig('subject', 'sub'),
      service_provider: service_provider.issuer,
    )
  end

  def user
    identity&.user
  end

  def occurred_at
    occurred_at_int = event.dig('occurred_at')
    Time.zone.at(occurred_at_int) if occurred_at_int
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
