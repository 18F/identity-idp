# frozen_string_literal: true

class OpenidConnectTokenExchangeForm
  include ActiveModel::Model

  ATTRS = %i[
    client_id
    grant_type
    subject_token
    subject_token_type
    audience
    resource
    requested_token_type
    scope
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
  validate :validate_scope, unless: :client_rejected?
  validate :validate_ial2, unless: :client_rejected?

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

    issued_token = TokenExchange::AccessTokenIssuer.issue(
      subject_token: loaded_subject_token,
      target_issuer: audience,
      resource:,
      scope: requested_scope,
    )

    {
      access_token: issued_token.token,
      issued_token_type: TokenExchange::Constants::ACCESS_TOKEN_TYPE,
      token_type: 'Bearer',
      expires_in: issued_token.expires_in,
      scope: requested_scope,
    }
  end

  # `invalid_client` indicates a client authentication failure, which RFC 6749
  # section 5.2 requires be returned with a 401.
  def http_status
    return :ok if valid?

    oauth_error == 'invalid_client' ? :unauthorized : :bad_request
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

    @identity = ServiceProviderIdentity.find_by(uuid: loaded_subject_token.identity_uuid)
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
      error_description: errors.full_messages.join(' '),
    }
  end

  # Maps validation failures onto the OAuth error codes defined by RFC 6749
  # section 5.2 and extended by RFC 8693 section 2.2.2.
  def oauth_error
    return 'invalid_request' if missing_required_attrs?
    return 'unsupported_grant_type' if errors.include?(:grant_type)
    return 'invalid_client' if errors.include?(:client_id)
    return 'invalid_target' if errors.include?(:audience) || errors.include?(:resource)
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
      client_id:,
      audience:,
      resource:,
      ial: subject_token_ial,
      integration_errors:,
    }
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
