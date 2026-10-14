# frozen_string_literal: true

class OpenidConnectIntrospectionForm
  include ActiveModel::Model
  include ActionView::Helpers::TranslationHelper
  include Rails.application.routes.url_helpers

  ATTRS = %i[
    client_assertion
    client_assertion_type
    client_id
    token
    token_type_hint
  ].freeze

  attr_reader(*ATTRS)

  validates :client_assertion, :client_assertion_type, :client_id, :token, presence: true
  validates :client_assertion_type,
            inclusion: { in: [TokenExchange::Constants::CLIENT_ASSERTION_TYPE] }

  validate :validate_enabled
  validate :validate_client, if: :token_exchange_enabled?
  validate :validate_target_allowlisted, if: :token_exchange_enabled?
  validate :validate_client_assertion, if: :token_exchange_enabled?

  def initialize(params)
    ATTRS.each do |key|
      instance_variable_set(:"@#{key}", params[key])
    end
  end

  def submit
    success = valid?
    FormResponse.new(success:, errors:, extra: {})
  end

  def response
    return error_response unless valid?
    return inactive_response unless token_active_for_client?

    active_response
  end

  def url_options
    {}
  end

  private

  def token_exchange_enabled?
    IdentityConfig.store.token_exchange_enabled
  end

  def validate_enabled
    return if token_exchange_enabled?

    errors.add(:client_id, :invalid)
  end

  def validate_client
    errors.add(:client_id, :invalid) unless service_provider
  end

  def validate_target_allowlisted
    return if service_provider.blank?
    return if token_exchange_allowed_target_issuers.include?(client_id)

    errors.add(:client_id, :invalid)
  end

  def validate_client_assertion
    return if service_provider.blank?
    return if errors.include?(:client_id)

    validator = OpenidConnectClientAssertionValidator.new(
      client_assertion:,
      client_id:,
      service_provider:,
      audience_url: api_openid_connect_introspect_url,
    )
    validator.errors.each do |error|
      errors.add(error.attribute, error.message, type: error.type)
    end
  end

  def token_active_for_client?
    access_token.present? &&
      access_token.target_issuer == client_id &&
      access_token.active?
  end

  def active_response
    {
      active: true,
      client_id: access_token.broker_issuer,
      sub: access_token.target_issuer,
      iss: root_url,
      exp: access_token.expires_at,
      iat: access_token.issued_at,
      aud: access_token.target_issuer,
      act: {
        sub: access_token.broker_issuer,
      },
      scope: access_token.scope,
    }
  end

  def inactive_response
    { active: false }
  end

  def error_response
    {
      error: 'invalid_client',
      error_description: errors.full_messages.join(' '),
    }
  end

  def service_provider
    @service_provider ||= ServiceProvider.active.find_by(issuer: client_id)
  end

  def token_exchange_allowed_target_issuers
    Array(IdentityConfig.store.token_exchange_allowed_target_issuers)
  end

  def access_token
    return @access_token if defined?(@access_token)

    @access_token = TokenExchange::AccessToken.load(token)
  end
end
