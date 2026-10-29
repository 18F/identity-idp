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
    dpop_proof
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
  validate :validate_dpop_proof, if: :dpop_binding_required?

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
    elsif errors.include?(:dpop_proof)
      # RFC 9449 §5: one error code for every proof problem, with the reason as the description.
      { error: 'invalid_dpop_proof', error_description: errors[:dpop_proof].join(' ') }
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
    issued_token = TokenExchange::SubjectTokenIssuer.issue(
      identity:,
      actor_return_log_id: actor_handoff&.actor_return_log_id,
      dpop_jkt: bound_thumbprint,
    )
    {
      access_token: issued_token.token,
      # RFC 9449 §5: a token bound to the client's key is presented with a proof, never as a
      # bearer token.
      token_type: dpop_binding_required? ? 'DPoP' : 'Bearer',
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

  # Whether the code being redeemed must be accompanied by a DPoP proof (RFC 9449 §5, §10). A
  # property of the client, not of the request: a public client registered for key binding holds
  # its tokens in the person's browser, so its authorization code was bound to its key's
  # thumbprint at the authorization request. Every other client is unaffected.
  def dpop_binding_required?
    identity.present? && service_provider.present? && service_provider.dpop_required?
  end

  # Runs after every other check so a proof problem is reported only for an otherwise valid
  # redemption and a rejected request never consumes the proof's single-use jti. The proof must be
  # for POST to this endpoint and signed by the key whose thumbprint the authorization request
  # named; no token accompanies a code redemption, so the proof carries no `ath`.
  def validate_dpop_proof
    return if errors.any?

    if bound_thumbprint.blank?
      errors.add(
        :dpop_proof, 'dpop_code_unbound', type: :dpop_code_unbound
      )
      return
    end

    return if dpop_result.success?

    errors.add(
      :dpop_proof, dpop_result.first_error_message, type: dpop_result.extra[:dpop_error_type]
    )
  end

  # Verified once per form: a proof's jti is single-use, so running the check again on the same
  # proof (validations run on every `valid?`) would report a replay of our own check.
  def dpop_result
    @dpop_result ||= DpopProofForm.new(
      proof: dpop_proof,
      http_method: 'POST',
      http_url: api_openid_connect_token_url,
      expected_thumbprint: bound_thumbprint,
    ).submit
  end

  # The thumbprint the authorization request named (RFC 9449 §10), kept with the code in its
  # hand-off record for the code's lifetime, so the binding expires with the code and nothing
  # about the key is written to the identity. Nil when the code was issued to a bearer client.
  def bound_thumbprint
    actor_handoff&.dpop_jkt if dpop_binding_required?
  end

  # The record Login.gov wrote when it issued this code: the actor's return log for a delegation
  # and the key thumbprint for a bound client. Loaded once; the code is the lookup key.
  def actor_handoff
    return @actor_handoff if defined?(@actor_handoff)

    @actor_handoff = TokenExchange::ActorHandoff.load(code)
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
      token_exchange_stage: token_exchange_stage,
      token_endpoint_operation: token_endpoint_operation,
      token_exchange_scopes: token_exchange_scope_values,
      integration_errors:,
      dpop_bound: dpop_binding_required? || nil,
      dpop_error_type: errors.details[:dpop_proof]&.first&.dig(:type),
    }
  end

  def token_endpoint_operation
    if token_exchange_authorization_code?
      TokenExchange::Constants::STAGE_SUBJECT_TOKEN
    else
      'authorization_code'
    end
  end

  def token_exchange_stage
    TokenExchange::Constants::STAGE_SUBJECT_TOKEN if token_exchange_authorization_code?
  end

  def token_exchange_scope_values
    scopes = identity&.scope.to_s.split(' ').select do |scope|
      TokenExchange::Constants.in_scope?(scope)
    end
    return if scopes.blank?

    scopes.map { |scope| scope.delete_prefix(TokenExchange::Constants::SCOPE_PREFIX) }
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
