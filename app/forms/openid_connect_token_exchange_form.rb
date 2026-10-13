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

  attr_reader(*ATTRS)

  validates :client_id,
            :grant_type,
            :subject_token,
            :subject_token_type,
            :audience,
            :resource,
            :requested_token_type,
            presence: true
  validates :grant_type, inclusion: { in: [TokenExchange::Constants::GRANT_TYPE] }
  validates :subject_token_type,
            inclusion: { in: [TokenExchange::Constants::ACCESS_TOKEN_TYPE] }
  validates :requested_token_type,
            inclusion: { in: [TokenExchange::Constants::ACCESS_TOKEN_TYPE] }

  validate :validate_enabled
  validate :validate_broker
  validate :validate_subject_token
  validate :validate_target
  validate :validate_resource
  validate :validate_scope
  validate :validate_ial2

  def initialize(params)
    ATTRS.each do |key|
      instance_variable_set(:"@#{key}", params[key])
    end
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

  private

  def validate_enabled
    return if IdentityConfig.store.token_exchange_enabled

    errors.add(:grant_type, :inclusion)
  end

  def validate_broker
    return if broker&.token_exchange_broker?

    errors.add(:client_id, :invalid)
  end

  def validate_subject_token
    return errors.add(:subject_token, :invalid) if loaded_subject_token.blank?
    return if loaded_subject_token.broker_issuer == client_id

    errors.add(:subject_token, :invalid)
  end

  def validate_target
    return errors.add(:audience, :invalid) unless target
    return if token_exchange_allowed_target_issuers.include?(audience)

    errors.add(:audience, :invalid)
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
    return if loaded_subject_token.blank?
    return if loaded_subject_token.ial.to_i >= 2

    errors.add(:subject_token, :invalid)
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

  def token_exchange_allowed_target_issuers
    Array(IdentityConfig.store.token_exchange_allowed_target_issuers)
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

  def oauth_error
    return 'unsupported_grant_type' if errors.include?(:grant_type)
    return 'invalid_target' if errors.include?(:audience)
    return 'invalid_client' if errors.include?(:client_id)

    'invalid_grant'
  end

  def extra_analytics_attributes
    {
      client_id:,
      user_id: nil,
      code_digest: nil,
      code_verifier_present: false,
      service_provider_pkce: broker&.pkce,
      ial: loaded_subject_token&.ial,
      integration_errors:,
    }
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
