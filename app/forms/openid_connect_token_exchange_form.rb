# frozen_string_literal: true

# Handles `grant_type=urn:ietf:params:oauth:grant-type:token-exchange` at the token endpoint
# (RFC 8693). A service provider presents the access token Login.gov issued to it for a signed-in
# person (the `subject_token`) and names one agency API (`resource`, RFC 8707); if the person
# approved the application that owns that API for this service provider, Login.gov issues an
# opaque token the API verifies by introspection.
#
# How the caller proves who it is depends on its client type, fixed at onboarding:
#
# * A confidential service provider authenticates with a `private_key_jwt` client assertion
#   (RFC 7523) signed with a key on its record. It receives a bearer token.
# * A public service provider (PKCE, no secret; its tokens live in the person's browser) sends its
#   `client_id` and a DPoP proof (RFC 9449 §4.3) signed by the key its own access token is bound
#   to, with `ath` over that token. A stolen subject token is therefore useless without the key.
#   It receives a token bound to the same key, reported as `token_type: DPoP`.
#
# The checks run in a fixed order, each stopping at the first failure, so nothing about the
# registry or the person's approvals is revealed to a caller that has not authenticated, and each
# failure maps to the RFC 6749 §5.2 / RFC 8693 §2.2.2 / RFC 9449 §5 code the service provider
# should act on:
#
# * `invalid_client`      - no or wrong client credentials, or a client not approved for delegation
# * `invalid_request`     - malformed request (token types, missing parameters, PKCE offered,
#                           more than one resource)
# * `invalid_grant`       - the subject token is not this client's, its sign-in has ended, or the
#                           person is not identity-verified
# * `invalid_dpop_proof`  - a public client's proof is missing or fails verification
# * `invalid_target`      - the resource is unknown or inactive, its application does not accept
#                           this client, or the requested format is not available for it
# * `consent_required`    - the person has not approved the application that owns the resource,
#                           or the approval lapsed; the description names the scope to request
#
# The exchange never touches the application's `identities` row and never returns an
# `id_token`: the agency learns who the person is only by introspecting the token.
class OpenidConnectTokenExchangeForm
  include ActiveModel::Model
  include ActionView::Helpers::TranslationHelper
  include Rails.application.routes.url_helpers

  GRANT_TYPE = 'urn:ietf:params:oauth:grant-type:token-exchange'
  CLIENT_ASSERTION_TYPE = OpenidConnectTokenForm::CLIENT_ASSERTION_TYPE
  ACCESS_TOKEN_TYPE = 'urn:ietf:params:oauth:token-type:access_token'
  SAML2_TOKEN_TYPE = 'urn:ietf:params:oauth:token-type:saml2'
  REQUESTED_TOKEN_TYPES = [ACCESS_TOKEN_TYPE, SAML2_TOKEN_TYPE].freeze

  ATTRS = %i[
    client_assertion
    client_assertion_type
    client_id
    code_verifier
    dpop_proof
    requested_token_type
    resource
    subject_token
    subject_token_type
  ].freeze

  attr_reader(*ATTRS)

  validate :validate_client
  validate :validate_request_shape
  validate :validate_subject_token
  validate :validate_public_client_proof
  validate :validate_session_live
  validate :validate_identity_assurance
  validate :validate_resource
  validate :validate_requested_token_type
  validate :validate_grant

  def initialize(params)
    ATTRS.each do |key|
      instance_variable_set(:"@#{key}", params[key])
    end
  end

  def submit
    @success = valid?
    issue! if @success
    FormResponse.new(success: @success, errors:, extra: extra_analytics_attributes)
  end

  # RFC 8693 §2.2.1 response or the RFC error object. No `id_token`, no `refresh_token`.
  def response
    if @success
      {
        access_token: @access_token,
        issued_token_type: ACCESS_TOKEN_TYPE,
        token_type: @issued.token_type,
        expires_in: @issued.lifetime_seconds,
        scope: @issued.scope,
      }
    else
      { error: error_code, error_description: errors.map(&:message).join(' ') }
    end
  end

  def url_options
    {}
  end

  private

  attr_reader :service_provider, :identity, :resource_server, :grant, :error_code, :client_type

  # Records an error under the RFC code the service provider should act on. Only the first code
  # is reported, since later checks are skipped once one fails.
  def fail_with(attribute, code, message, type:)
    @error_code ||= code
    errors.add(attribute, message, type:)
  end

  def public_client?
    client_type == 'public'
  end

  # Identifies the caller and checks that it is a client this grant is open to. A confidential
  # client is authenticated here, by its client assertion; a public client is only identified
  # here (by `client_id`) and is authenticated by the proof it presents with its subject token
  # (#validate_public_client_proof). The two credentials are not interchangeable: the record says
  # which kind of client this is, and the other kind's credential is refused. Approval for
  # delegated access is a property of the client, so it is checked here too. PKCE never
  # substitutes for either credential on this grant.
  def validate_client
    if code_verifier.present?
      return fail_with(
        :code_verifier, 'invalid_request',
        t('openid_connect.token.errors.code_verifier_not_allowed'),
        type: :code_verifier_not_allowed
      )
    end

    if client_assertion.present? || client_assertion_type.present?
      authenticate_confidential_client
    elsif client_id.present?
      identify_public_client
    else
      fail_with(
        :client_id, 'invalid_client',
        t('openid_connect.token.errors.client_authentication_required'),
        type: :client_authentication_required
      )
    end
    return if errors.any? || service_provider.delegation_service_provider?

    fail_with(
      :client_id, 'invalid_client',
      t('openid_connect.token.errors.client_not_approved'),
      type: :client_not_approved
    )
  end

  def authenticate_confidential_client
    unless client_assertion_type == CLIENT_ASSERTION_TYPE
      return fail_with(
        :client_assertion_type, 'invalid_client',
        t('openid_connect.token.errors.client_assertion_type_invalid'),
        type: :client_assertion_type_invalid
      )
    end

    @auth_result = ResourceServerAuthenticator.new(
      client_assertion:, audience: api_openid_connect_token_url, key_source: :service_provider,
    ).call
    unless @auth_result.success?
      return fail_with(
        :client_assertion, 'invalid_client', @auth_result.error_message,
        type: @auth_result.error_type
      )
    end

    # A public client has no secret to sign with; a client assertion from one is a client
    # presenting the wrong kind of credential, not an authenticated public client.
    if @auth_result.record.pkce == true
      return fail_with(
        :client_assertion, 'invalid_client',
        t('openid_connect.token.errors.client_authentication_required'),
        type: :client_type_mismatch
      )
    end

    @service_provider = @auth_result.record
    @client_type = 'confidential'
  end

  def identify_public_client
    record = ServiceProvider.find_by(issuer: client_id) if client_id.exclude?("\x00")
    if record.nil?
      return fail_with(
        :client_id, 'invalid_client', t('openid_connect.token.errors.unknown_client'),
        type: :unknown_client
      )
    end

    # A confidential client must prove possession of its key; naming itself is not enough.
    unless record.pkce == true
      return fail_with(
        :client_id, 'invalid_client',
        t('openid_connect.token.errors.client_authentication_required'),
        type: :client_type_mismatch
      )
    end

    @service_provider = record
    @client_type = 'public'
  end

  # The parameters RFC 8693 §2.1 defines, with the restrictions Login.gov applies: the subject
  # is a Login.gov access token, the requested type is one of the two formats Login.gov issues
  # and must be stated, and exactly one resource is named so one token has one audience.
  def validate_request_shape
    return if errors.any?

    unless subject_token_type == ACCESS_TOKEN_TYPE
      return fail_with(
        :subject_token_type, 'invalid_request',
        t('openid_connect.token.errors.invalid_subject_token_type'),
        type: :invalid_subject_token_type
      )
    end
    if subject_token.blank? || subject_token.include?("\x00")
      return fail_with(
        :subject_token, 'invalid_request',
        t('openid_connect.token.errors.subject_token_missing'),
        type: :subject_token_missing
      )
    end
    if requested_token_type.blank?
      return fail_with(
        :requested_token_type, 'invalid_request',
        t('openid_connect.token.errors.requested_token_type_required'),
        type: :requested_token_type_required
      )
    end
    unless REQUESTED_TOKEN_TYPES.include?(requested_token_type)
      return fail_with(
        :requested_token_type, 'invalid_request',
        t('openid_connect.token.errors.invalid_requested_token_type'),
        type: :invalid_requested_token_type
      )
    end

    resources = Array(resource).map(&:to_s).reject(&:blank?)
    if resources.empty?
      fail_with(
        :resource, 'invalid_request', t('openid_connect.token.errors.resource_missing'),
        type: :resource_missing
      )
    elsif resources.size > 1
      fail_with(
        :resource, 'invalid_request', t('openid_connect.token.errors.multiple_resources'),
        type: :multiple_resources
      )
    end
  end

  # The subject token must be the access token Login.gov issued to *this* service provider for a
  # connection the person has not revoked. Tokens issued by exchange are not `identities` rows and
  # so can never be found here, which is what rules out chained delegation. For a public client
  # the token must also be bound to a key, which its authorization request guaranteed.
  def validate_subject_token
    return if errors.any?

    @identity = ServiceProviderIdentity.not_deleted.find_by(access_token: subject_token)
    return unless identity.nil? || identity.user.nil? ||
                  identity.service_provider != service_provider.issuer ||
                  (public_client? && identity.dpop_jkt.blank?)

    @identity = nil
    fail_with(
      :subject_token, 'invalid_grant', t('openid_connect.token.errors.invalid_subject_token'),
      type: :invalid_subject_token
    )
  end

  # A public client is authenticated by possession of the key its subject token is bound to:
  # the proof must be for POST to this endpoint, signed by that key (thumbprint equal to the
  # token's binding) and carry `ath` over the subject token (RFC 9449 §4.3, §7.1). Every failure
  # is `invalid_dpop_proof` (§5).
  def validate_public_client_proof
    return if errors.any? || !public_client?

    result = DpopProofVerifier.new(
      proof: dpop_proof,
      http_method: 'POST',
      http_url: api_openid_connect_token_url,
      access_token: subject_token,
      expected_thumbprint: identity.dpop_jkt,
    ).call
    return if result.success?

    fail_with(:dpop_proof, 'invalid_dpop_proof', result.error_message, type: result.error_type)
  end

  # A Login.gov access token is honored only while the sign-in that issued it is live (the same
  # rule userinfo applies), so an old or copied token cannot start a delegation later.
  def validate_session_live
    return if errors.any?
    return if OutOfBandSessionAccessor.new(identity.rails_session_id).ttl.positive?

    fail_with(
      :subject_token, 'invalid_grant',
      t('openid_connect.token.errors.subject_token_session_ended'),
      type: :subject_token_session_ended
    )
  end

  # Delegation is offered only for identity-verified people: the service provider signed the
  # person in at IAL2 (or IALmax, which is IAL2 for a verified person), the person still holds an
  # active profile, and the account is in good standing.
  def validate_identity_assurance
    return if errors.any?

    unless identity_verified?
      return fail_with(
        :subject_token, 'invalid_grant',
        t('openid_connect.token.errors.identity_not_verified'),
        type: :identity_not_verified
      )
    end
    return unless identity.user.suspended?

    fail_with(
      :subject_token, 'invalid_grant', t('openid_connect.token.errors.user_suspended'),
      type: :user_suspended
    )
  end

  # `resource` must name a registered API URL that is usable (it, its application and the
  # application's agency are active) and whose application accepts this service provider. Each
  # of those failures is reported the same way so the endpoint does not describe the registry.
  def validate_resource
    return if errors.any?

    @resource_server = TokenExchangeResourceServer.includes(service_provider: :agency)
      .find_by(identifier: resource)
    return if resource_server&.usable? &&
              resource_server.service_provider.accepts_delegation_from?(service_provider.issuer)

    @resource_server = nil
    fail_with(
      :resource, 'invalid_target', t('openid_connect.token.errors.unknown_resource'),
      type: :unknown_resource
    )
  end

  # Which format to issue for the named API. An access token is issued here; a SAML assertion is
  # not available, so a request for one is refused as a target problem.
  def validate_requested_token_type
    return if errors.any?

    case requested_token_type
    when ACCESS_TOKEN_TYPE then nil
    when SAML2_TOKEN_TYPE
      fail_with(
        :requested_token_type, 'invalid_target',
        t('openid_connect.token.errors.saml_not_available'),
        type: :saml_not_available
      )
    end
  end

  # The person's live, current approval of the application that owns the resource, for this
  # service provider. A single-authorization approval counts only when it was given in the
  # sign-in the subject token belongs to, which the identity's browser session identifies. With
  # no such approval the client is told which scope to request so it can start a sign-in that
  # asks for it; by now the caller is authenticated and the resource is known to exist.
  def validate_grant
    return if errors.any?

    @grant = TokenExchangeGrant.live_by_application(
      user: identity.user, service_provider_issuer: service_provider.issuer,
      applications: [application]
    )[application.id]
    current = grant.present? && grant.valid_now?(
      current_authorization: grant.rails_session_id.present? &&
                             grant.rails_session_id == identity.rails_session_id,
    )
    return if current

    @grant = nil
    fail_with(
      :resource, 'consent_required',
      t(
        'openid_connect.token.errors.consent_required',
        delegation_scope: application.delegation_scope,
      ),
      type: :consent_required
    )
  end

  def application
    resource_server&.service_provider
  end

  def identity_verified?
    return false if identity.user.active_profile.nil?
    [::Idp::Constants::IAL2, ::Idp::Constants::IAL_MAX].include?(identity.ial)
  end

  # The authentication assurance of the service provider's sign-in, as an integer level: the
  # value recorded on the identity when the sign-in stored one, otherwise resolved from the
  # authentication context the sign-in was performed under.
  def forwarded_aal
    return identity.aal if identity.aal.present?
    return nil if identity.acr_values.blank?

    acr = AuthnContextResolver.new(
      user: identity.user, service_provider:, acr_values: identity.acr_values,
    ).asserted_aal_acr
    Saml::Idp::Constants::AUTHN_CONTEXT_CLASSREF_TO_AAL[acr]
  end

  # Lifetime: the configured default, or the API's own maximum when that is lower; never longer.
  def access_token_lifetime
    [
      IdentityConfig.store.token_exchange_access_token_ttl_seconds,
      resource_server.max_access_token_seconds,
    ].compact.min
  end

  # Issues the token: the issuance record is written first, in one transaction with the
  # approval's first-exchange timestamp, and the live token is written to Redis only once that
  # has committed, so a token can never be live without its record. The token string exists
  # only in this process and in the response.
  def issue!
    now = Time.zone.now
    lifetime = access_token_lifetime
    @access_token = TokenExchangeToken.generate_token
    dpop_jkt = identity.dpop_jkt if public_client?

    TokenExchangeToken.transaction do
      @issued = TokenExchangeToken.create!(
        grant:,
        resource_server:,
        service_provider:,
        user: identity.user,
        delegation_id: grant.delegation_id,
        scope: application.delegation_scope,
        ial: identity.ial,
        aal: forwarded_aal,
        refresh_family_id: SecureRandom.uuid,
        token_type: public_client? ? 'DPoP' : 'Bearer',
        token_format: 'oauth',
        dpop_jkt:,
        sp_rails_session_id: identity.rails_session_id,
        issued_at: now,
        expires_at: now + lifetime.seconds,
      )
      grant.update!(first_exchanged_at: now) if grant.first_exchanged_at.nil?
    end

    DelegatedTokenStore.write(
      @access_token,
      {
        aud: resource_server.identifier,
        scope: @issued.scope,
        grant_id: grant.id,
        delegation_id: grant.delegation_id,
        user_id: identity.user_id,
        service_provider_id: service_provider.id,
        resource_server_id: resource_server.id,
        ial: @issued.ial,
        aal: @issued.aal,
        refresh_family_id: @issued.refresh_family_id,
        dpop_jkt:,
        token_type: @issued.token_type,
        token_format: @issued.token_format,
        sp_rails_session_id: identity.rails_session_id,
        issued_at: now.to_i,
        expires_at: @issued.expires_at.to_i,
        issuance_id: @issued.id,
      },
      ttl: lifetime,
    )
  end

  # The issuer the caller claimed, authenticated or not, so failures can be attributed.
  def claimed_issuer
    service_provider&.issuer || @auth_result&.claimed_identifier || client_id.presence
  end

  def extra_analytics_attributes
    {
      service_provider_issuer: claimed_issuer,
      resource_server_identifier: resource_server&.identifier,
      application_issuer: application&.issuer,
      client_type:,
      token_type: @issued&.token_type,
      requested_token_type:,
      error_code:,
      integration_errors:,
    }
  end

  def integration_errors
    return nil if @success || claimed_issuer.blank?

    {
      error_details: errors.full_messages,
      error_types: errors.attribute_names,
      event: :oidc_token_exchange_request,
      integration_exists: service_provider.present? ||
        ServiceProvider.exists?(issuer: claimed_issuer),
      request_issuer: claimed_issuer,
    }
  end
end
