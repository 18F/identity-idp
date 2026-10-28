# frozen_string_literal: true

class OpenidConnectTokenForm
  include ActiveModel::Model
  include ActionView::Helpers::TranslationHelper
  include Rails.application.routes.url_helpers

  ATTRS = %i[
    client_assertion
    client_assertion_type
    code
    code_verifier
    grant_type
  ].freeze

  attr_reader(*ATTRS)

  CLIENT_ASSERTION_TYPE = 'urn:ietf:params:oauth:client-assertion-type:jwt-bearer'

  validates_inclusion_of :grant_type, in: %w[authorization_code]
  validates_inclusion_of :client_assertion_type,
                         in: [CLIENT_ASSERTION_TYPE],
                         if: :client_assertion_required?

  validate :validate_expired
  validate :validate_code
  validate :validate_pkce_or_private_key_jwt
  validate :validate_code_verifier, if: :pkce_verification_required?
  validate :validate_client_assertion, if: :client_assertion_required?

  def initialize(params)
    ATTRS.each do |key|
      instance_variable_set(:"@#{key}", params[key])
    end
    code_expiration_secs = IdentityConfig.store.openid_connect_authorization_code_expiration_seconds
    @code_expiration = code_expiration_secs.seconds.ago
    @identity = find_identity_with_code
  end

  def submit
    success = valid?

    clear_authorization_code if success

    FormResponse.new(success: success, errors: errors, extra: extra_analytics_attributes)
  end

  def response
    if valid?
      return token_exchange_subject_token_response if token_exchange_authorization_code?

      id_token_builder = IdTokenBuilder.new(identity: identity, code: code)
      @ttl = id_token_builder.ttl

      {
        access_token: identity.access_token,
        token_type: 'Bearer',
        expires_in: @ttl,
        id_token: id_token_builder.id_token,
      }
    elsif private_key_jwt_pkce? && errors.include?(:code_verifier)
      { error: 'invalid_grant',
        error_description: t('openid_connect.token.errors.invalid_code_verifier') }
    else
      { error: errors.to_a.join(' ') }
    end
  end

  def url_options
    {}
  end

  # The authorization code grant has always returned 400 for every failure.
  # Preserved here so the token endpoint can ask either form for its status.
  def http_status
    valid? ? :ok : :bad_request
  end

  private

  attr_reader :identity, :code_expiration

  def token_exchange_subject_token_response
    actor_handoff = TokenExchange::ActorHandoff.load(code)
    issued_token = TokenExchange::SubjectTokenIssuer.issue(
      identity:,
      actor_return_log_id: actor_handoff&.actor_return_log_id,
    )
    {
      access_token: issued_token.token,
      token_type: 'Bearer',
      expires_in: issued_token.expires_in,
      scope: identity.scope,
    }
  end

  def token_exchange_authorization_code?
    return false unless IdentityConfig.store.token_exchange_enabled &&
                        service_provider&.token_exchange_broker?
    return false if identity.blank?

    token_exchange_scope_requested?
  end

  def token_exchange_scope_requested?
    identity.scope.to_s.split(' ').any? do |scope|
      TokenExchange::Constants.in_scope?(scope)
    end
  end

  def find_identity_with_code
    return if code.blank? || code.include?("\x00")

    @identity = ServiceProviderIdentity
      .where(session_uuid: code)
      .order(updated_at: :desc).first
  end

  def private_key_jwt_pkce?
    # Match the complete code before interpreting its prefix; never strip it for lookup.
    # Use the submitted code because successful redemption clears identity.session_uuid.
    identity.present? && code.start_with?(IdentityLinker::PRIVATE_KEY_JWT_PKCE_CODE_PREFIX)
  end

  def pkce_verification_required?
    private_key_jwt_pkce? ||
      (pkce_authentication_allowed? &&
        (code_verifier.present? || identity.try(:code_challenge).present?))
  end

  def client_assertion_required?
    private_key_jwt_pkce? || (!service_provider&.pkce && client_assertion_provided?)
  end

  def client_assertion_provided?
    client_assertion.present? || client_assertion_type.present?
  end

  def pkce_authentication_allowed?
    pkce = service_provider&.pkce
    pkce.nil? || pkce
  end

  def validate_pkce_or_private_key_jwt
    return if (pkce_authentication_allowed? && pkce_verification_required?) ||
              (client_assertion_required? && client_assertion_provided?)
    errors.add :code,
               t('openid_connect.token.errors.invalid_authentication'),
               type: :invalid_authentication
  end

  def validate_expired
    if identity&.updated_at && identity.updated_at < code_expiration
      errors.add :code, t('openid_connect.token.errors.expired_code'), type: :expired_code
    end
  end

  def validate_code
    if identity.blank? || !identity.user
      errors.add :code,
                 t('openid_connect.token.errors.invalid_code'),
                 type: :invalid_code
    end
  end

  def validate_code_verifier
    if valid_code_verifier? && expected_code_challenge && code_verifier_matches_challenge?
      return
    end

    errors.add :code_verifier,
               t('openid_connect.token.errors.invalid_code_verifier'),
               type: :invalid_code_verifier
  end

  def valid_code_verifier?
    # Existing PKCE integrations retain their previous verifier validation.
    return true unless private_key_jwt_pkce?
    code_verifier.is_a?(String) && code_verifier.match?(/\A[A-Za-z0-9._~-]{43,128}\z/)
  end

  def expected_code_challenge
    remove_base64_padding(identity.try(:code_challenge))
  end

  def code_verifier_matches_challenge?
    given_code_challenge = Digest::SHA256.urlsafe_base64digest(code_verifier.to_s)
    ActiveSupport::SecurityUtils.secure_compare(expected_code_challenge, given_code_challenge)
  end

  def validate_client_assertion
    return if identity.blank?

    validator = OpenidConnectClientAssertionValidator.new(
      client_assertion:,
      client_id:,
      service_provider:,
      audience_url: api_openid_connect_token_url,
    )
    validator.errors.each do |error|
      errors.add(error.attribute, error.message, type: error.type)
    end
  end

  def service_provider
    return @service_provider if defined?(@service_provider)
    @service_provider = ServiceProvider.find_by(issuer: client_id)
  end

  def client_id
    identity.try(:service_provider)
  end

  def remove_base64_padding(data)
    Base64.urlsafe_encode64(Base64.urlsafe_decode64(data.to_s), padding: false)
  rescue ArgumentError
    nil
  end

  def extra_analytics_attributes
    {
      client_id: client_id,
      user_id: identity&.user&.uuid,
      code_digest: code ? Digest::SHA256.hexdigest(code) : nil,
      code_verifier_present: code_verifier.present?,
      service_provider_pkce: service_provider&.pkce,
      ial: identity&.ial,
      integration_errors:,
    }
  end

  def integration_errors
    return nil if valid? || client_id.blank?

    {
      error_details: errors.full_messages,
      error_types: errors.attribute_names,
      event: :oidc_token_request,
      integration_exists: service_provider.present?,
      request_issuer: client_id,
    }
  end

  def clear_authorization_code
    identity.update(session_uuid: nil)
  end
end
