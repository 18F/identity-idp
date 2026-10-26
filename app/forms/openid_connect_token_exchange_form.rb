# frozen_string_literal: true

class OpenidConnectTokenExchangeForm
  include ActiveModel::Model
  include ActionView::Helpers::TranslationHelper
  include Rails.application.routes.url_helpers

  ATTRS = %i[
    client_id
    grant_type
    subject_token
    subject_token_type
    audience
    resource
    requested_token_type
    scope
    dpop_proof
  ].freeze

  # Parameters RFC 8693 section 2.1 requires on every token exchange request.
  # Omitting any of them is an `invalid_request`, not a grant or target failure.
  REQUIRED_ATTRS = %i[
    client_id
    grant_type
    subject_token
    subject_token_type
    audience
    resource
    requested_token_type
  ].freeze

  attr_reader(*ATTRS)

  validates(*REQUIRED_ATTRS, presence: true)
  validates :grant_type, inclusion: { in: [TokenExchange::Constants::GRANT_TYPE] }
  validates :subject_token_type,
            inclusion: { in: [TokenExchange::Constants::ACCESS_TOKEN_TYPE] }
  validates :requested_token_type,
            inclusion: { in: [TokenExchange::Constants::ACCESS_TOKEN_TYPE] }

  # Ordered cheapest first.
  validate :validate_enabled
  validate :validate_broker
  validate :validate_target
  validate :validate_resource
  validate :validate_subject_token, unless: :client_rejected?
  validate :validate_actor_return_log, unless: :client_rejected?
  validate :validate_scope, unless: :client_rejected?
  validate :validate_ial2, unless: :client_rejected?
  validate :validate_dpop_proof, unless: :client_rejected?

  def initialize(params)
    ATTRS.each do |key|
      instance_variable_set(:"@#{key}", params[key])
    end
  end

  # Validations perform a Redis read and database lookups. The controller asks
  # the form whether it is valid more than once per request, so memoize the
  # result. Safe because the form is built once per request and is read-only.
  def valid?
    return @valid if defined?(@valid)

    @valid = super
  end

  def submit
    success = valid?
    FormResponse.new(success:, errors:, extra: extra_analytics_attributes)
  end

  def response
    return error_response unless valid?

    {
      access_token: issued_token.token,
      issued_token_type: TokenExchange::Constants::ACCESS_TOKEN_TYPE,
      # RFC 9449 §5: a token bound to the actor's key is presented with a proof, never as a bearer
      # token.
      token_type: bound_thumbprint ? 'DPoP' : 'Bearer',
      expires_in: issued_token.expires_in,
      scope: requested_scope,
    }
  end

  def delegation_id
    @issued_token&.delegation_id
  end

  # `invalid_client` indicates a client authentication failure, which RFC 6749
  # section 5.2 requires be returned with a 401.
  def http_status
    return :ok if valid?

    oauth_error == 'invalid_client' ? :unauthorized : :bad_request
  end

  def url_options
    {}
  end

  private

  def validate_enabled
    return if token_exchange_enabled?

    errors.add(:grant_type, :inclusion)
  end

  def token_exchange_enabled?
    IdentityConfig.store.token_exchange_enabled
  end

  # True once the feature flag, the broker allowlist, or the target allowlist
  # has already rejected this request, so the remaining validations can skip
  # the Redis read and the identity lookup entirely.
  def client_rejected?
    !token_exchange_enabled? ||
      errors.include?(:client_id) ||
      errors.include?(:audience)
  end

  def validate_broker
    return if client_id.blank?
    return if broker&.token_exchange_broker?

    errors.add(:client_id, :invalid)
  end

  def validate_target
    return if audience.blank?
    return if target&.token_exchange_target?

    errors.add(:audience, :invalid)
  end

  def validate_subject_token
    return if subject_token.blank?
    return errors.add(:subject_token, :invalid) if loaded_subject_token.blank?
    return if loaded_subject_token.broker_issuer == client_id

    errors.add(:subject_token, :invalid)
  end

  def validate_actor_return_log
    return if loaded_subject_token.blank?
    return if actor_return_log.present?

    errors.add(:subject_token, :invalid)
  end

  def validate_resource
    return if resource.blank?

    uri = URI.parse(resource)
    return if uri.is_a?(URI::HTTPS) && uri.host.present?

    errors.add(:resource, :invalid)
  rescue URI::InvalidURIError
    errors.add(:resource, :invalid)
  end

  def validate_scope
    return if loaded_subject_token.blank? || requested_scope.blank?

    requested_scopes = requested_scope.split(' ')
    subject_scopes = loaded_subject_token.scope.to_s.split(' ')
    return if (requested_scopes - subject_scopes).blank?

    errors.add(:scope, :invalid)
  end

  # An actor registered for key binding proves possession of the key its subject token is bound to
  # (RFC 9449 §7.1): the proof is for POST to this endpoint, carries `ath` over the subject token as
  # presented, and is signed by the key whose thumbprint the subject token recorded at the code
  # exchange. It runs last, so a request refused for any other reason never consumes the proof's
  # single-use jti. An actor not registered for key binding is a bearer client; a DPoP header it
  # sends is not read.
  def validate_dpop_proof
    return unless dpop_binding_required?
    return if errors.any?

    if loaded_subject_token.dpop_jkt.blank?
      errors.add(
        :dpop_proof, t('openid_connect.token.errors.dpop_subject_token_unbound'),
        type: :dpop_subject_token_unbound
      )
      return
    end

    return if dpop_result.success?

    errors.add(
      :dpop_proof, dpop_result.first_error_message, type: dpop_result.extra[:dpop_error_type]
    )
  end

  def dpop_binding_required?
    broker.present? && broker.dpop_required?
  end

  # Verified once per form: the proof's jti is single-use, so a second run of the check on the
  # same proof (validations run on every `valid?`) would report a replay of our own check.
  def dpop_result
    @dpop_result ||= DpopProofForm.new(
      proof: dpop_proof,
      http_method: 'POST',
      http_url: api_openid_connect_token_url,
      access_token: subject_token,
      expected_thumbprint: loaded_subject_token.dpop_jkt,
    ).submit
  end

  # The thumbprint the delegated token is bound to (its `cnf.jkt`), when the actor is key-bound.
  def bound_thumbprint
    loaded_subject_token.dpop_jkt if dpop_binding_required?
  end

  def validate_ial2
    return if subject_token.blank?
    return if loaded_subject_token.blank?
    return errors.add(:subject_token, :invalid) if loaded_subject_token.ial.to_i < 2
    return errors.add(:subject_token, :invalid) if user.blank?
    return if user.identity_verified?

    errors.add(:subject_token, :invalid)
  end

  def user
    identity&.user
  end

  def identity
    return @identity if defined?(@identity)
    return @identity = nil if loaded_subject_token.blank?

    @identity = ServiceProviderIdentity.find_by(
      uuid: loaded_subject_token.identity_uuid,
      service_provider: loaded_subject_token.broker_issuer,
    )
  end

  def actor_return_log
    return @actor_return_log if defined?(@actor_return_log)
    return @actor_return_log = nil if identity.blank?

    @actor_return_log = SpReturnLog.find_by(
      id: loaded_subject_token.actor_return_log_id,
      user_id: identity.user_id,
      issuer: loaded_subject_token.broker_issuer,
    )
  end

  def broker
    @broker ||= ServiceProvider.find_by(issuer: client_id)
  end

  def target
    @target ||= ServiceProvider.active.find_by(issuer: audience)
  end

  def loaded_subject_token
    return @loaded_subject_token if defined?(@loaded_subject_token)

    @loaded_subject_token = TokenExchange::SubjectToken.load(subject_token)
  end

  def requested_scope
    scope.presence || loaded_subject_token&.scope
  end

  def error_response
    {
      error: oauth_error,
      error_description:,
    }
  end

  # A proof problem is described by the verifier's own message (RFC 9449 §5); every other
  # failure keeps the attribute-prefixed messages the endpoint has always returned.
  def error_description
    return errors[:dpop_proof].join(' ') if errors.include?(:dpop_proof)

    errors.full_messages.join(' ')
  end

  # Maps validation failures onto the OAuth error codes defined by RFC 6749
  # section 5.2 and extended by RFC 8693 section 2.2.2.
  def oauth_error
    return 'invalid_request' if missing_required_attrs?
    return 'unsupported_grant_type' if errors.include?(:grant_type)
    return 'invalid_client' if errors.include?(:client_id)
    return 'invalid_target' if errors.include?(:audience) || errors.include?(:resource)
    return 'invalid_dpop_proof' if errors.include?(:dpop_proof)
    return 'invalid_scope' if errors.include?(:scope)

    'invalid_grant'
  end

  def missing_required_attrs?
    REQUIRED_ATTRS.any? do |attr|
      errors.where(attr, :blank).any?
    end
  end

  def extra_analytics_attributes
    {
      actor_issuer: client_id,
      target_issuer: audience,
      resource:,
      ial: subject_token_ial,
      token_exchange_stage: TokenExchange::Constants::STAGE_DELEGATED_TOKEN,
      token_exchange_scopes: token_exchange_scope_values,
      subject_token_fingerprint: subject_token_fingerprint,
      oauth_error_code: (oauth_error unless valid?),
      integration_errors:,
      dpop_bound: dpop_binding_required? || nil,
      dpop_error_type: errors.details[:dpop_proof]&.first&.dig(:type),
    }
  end

  def issued_token
    @issued_token ||= TokenExchange::AccessTokenIssuer.issue(
      subject_token: loaded_subject_token,
      target_issuer: audience,
      resource:,
      scope: requested_scope,
      dpop_jkt: bound_thumbprint,
    )
  end

  def token_exchange_scope_values
    scopes = requested_scope.to_s.split(' ').select do |scope|
      TokenExchange::Constants.in_scope?(scope)
    end
    return if scopes.blank?

    scopes.map { |scope| scope.delete_prefix(TokenExchange::Constants::SCOPE_PREFIX) }
  end

  def subject_token_fingerprint
    TokenExchange::SubjectToken.digest(subject_token) if subject_token.present?
  end

  # Reports the IAL only when a validation already loaded the subject token.
  # Analytics must not be the thing that triggers the Redis read for a request
  # we rejected before reaching it.
  def subject_token_ial
    return unless defined?(@loaded_subject_token)

    @loaded_subject_token&.ial
  end

  def integration_errors
    return nil if valid?

    {
      error_details: errors.full_messages,
      error_types: errors.attribute_names,
      event: :oidc_token_request,
      integration_exists: broker.present?,
      request_issuer: client_id,
    }
  end
end
