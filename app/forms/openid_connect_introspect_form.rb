# frozen_string_literal: true

# RFC 7662 introspection of a delegated token.
#
# Who is asking decides what is answered:
#
# * A resource server (an agency API) authenticates with a `private_key_jwt` client assertion
#   (RFC 7523) signed with a key on its own registration, `aud` naming this endpoint. For a token
#   whose audience is that API it receives the full active response: the token members RFC 7662
#   §2.2 defines, `act` naming the service provider acting for the person (RFC 8693 §4.1), the
#   delegation identifier, the assurance of the sign-in, and the person's identity as the agency
#   would read it from userinfo after a direct sign-in (DelegatedTokenClaims).
# * The public-client service provider holding a token identifies itself with `client_id` and
#   proves possession of the key the token is bound to with a DPoP proof (RFC 9449 §4.3) whose
#   `ath` is over the `token` parameter. For its own token it receives the limited response: the
#   token's status and lifetime, audience and access, the delegation identifier, the key binding,
#   the person's identifier as its own sign-in already reports it, and any attribute the
#   application has chosen to share with service providers. Nothing else about the person.
# * Anyone else receives exactly `{"active": false}` (RFC 7662 §2.2): an authenticated resource
#   server asking about another API's token, a service provider whose proof key is not the one
#   the token is bound to or whose token was issued to a different service provider, a
#   confidential service provider, a caller naming no credential at all. The endpoint never says
#   whether a token exists, whose it is, or why it stopped working, so a party holding a token it
#   should not have cannot use it as an oracle.
#
# A credential that is presented and fails is HTTP 401 (RFC 7662 §2.3): the RFC 6749 §5.2
# `invalid_client` error for an assertion that does not verify, and the RFC 9449 §5
# `invalid_dpop_proof` error with a `WWW-Authenticate: DPoP` challenge (§7.1) for a proof that
# does not verify or is missing. Neither says anything about the token.
#
# The token is read from Redis by its digest (DelegatedTokenStore); an absent entry is "not
# active" whether the token never existed, expired or was revoked. A present entry is active only
# while its expiry is in the future, the approval it was issued under still authorizes delegation,
# the API with its application and agency is usable, the service provider is still approved and
# active, and the person's account is in good standing.
class OpenidConnectIntrospectForm
  include ActiveModel::Model
  include ActionView::Helpers::TranslationHelper
  include DelegatedAccessClientHandling

  CALLER_TYPES = %i[resource_server service_provider none].freeze

  ATTRS = %i[
    client_assertion
    client_assertion_type
    client_id
    dpop_proof
    token
    token_type_hint
  ].freeze

  attr_reader(*ATTRS)

  def initialize(params)
    ATTRS.each do |key|
      instance_variable_set(:"@#{key}", params[key])
    end
    @caller_type = :none
  end

  def submit
    identify_caller
    introspect if errors.empty?
    @success = errors.empty?
    FormResponse.new(success: @success, errors:, extra: extra_analytics_attributes)
  end

  def http_status
    @success ? :ok : :unauthorized
  end

  # The RFC 7662 §2.2 response, or the RFC 6749 §5.2 error object when the credential failed.
  def response
    return { active: false } if @success && !@active
    return active_response if @success

    error_response
  end

  # The RFC 9449 §7.1 challenge for a failed or missing proof; nil for every other outcome.
  def www_authenticate
    return nil if @success || caller_type != :service_provider

    description = errors.map(&:message).join(' ').gsub(/["\\]/, '')
    %(DPoP algs="#{DpopProofVerifier::ALLOWED_ALGORITHMS.join(' ')}", ) +
      %(error="#{error_code}", error_description="#{description}")
  end

  private

  attr_reader :caller_type, :entry, :user, :grant, :identity,
              :token_resource_server, :token_service_provider

  # A client assertion, or even just its type, means a resource server is authenticating; a bare
  # `client_id` means a public client is naming itself. A request with neither has no credential
  # and is answered "not active" without further examination.
  def identify_caller
    if client_assertion.present? || client_assertion_type.present?
      @caller_type = :resource_server
      authenticate_confidential_client
    elsif client_id.present?
      identify_service_provider
    end
  end

  def client_assertion_audience
    api_openid_connect_introspect_url
  end

  # The confidential caller here is an agency API, verified against the keys on its own
  # registration (TokenExchangeResourceServer#ssl_certs).
  def client_key_source
    :resource_server
  end

  # @param record [TokenExchangeResourceServer]
  def confidential_client_authenticated(record)
    @caller_resource_server = record
  end

  # Only a registered public client approved for delegation can be the holder of a bound token,
  # so only such a name counts as a caller whose proof is then required. Any other name (a
  # confidential client, an unknown issuer) is not a credential and the answer is "not active".
  def identify_service_provider
    return if client_id.include?("\x00")

    record = ServiceProvider.find_by(issuer: client_id)
    return unless record&.pkce == true && record.delegation_service_provider?

    @caller_type = :service_provider
    @caller_service_provider = record
  end

  def introspect
    @entry = DelegatedTokenStore.read(token) unless token.to_s.include?("\x00")
    load_records if entry
    verify_service_provider_proof if caller_type == :service_provider
    return if errors.any?

    @active = token_active? && caller_entitled?
  end

  def load_records
    @user = User.find_by(id: entry[:user_id])
    @grant = TokenExchangeGrant.find_by(id: entry[:grant_id])
    @token_resource_server = TokenExchangeResourceServer.includes(service_provider: :agency)
      .find_by(id: entry[:resource_server_id])
    @token_service_provider = ServiceProvider.find_by(id: entry[:service_provider_id])
    return if user.nil? || token_service_provider.nil?

    @identity = ServiceProviderIdentity.not_deleted
      .find_by(user:, service_provider: token_service_provider.issuer)
  end

  # The proof must be a valid RFC 9449 proof for POST to this endpoint carrying `ath` over the
  # presented token. Whether its key is the one the token is bound to is decided with the
  # caller's entitlement, not here: a well-formed proof from another key is a caller that is not
  # the holder, answered "not active", so a party holding a token without its key learns nothing.
  def verify_service_provider_proof
    result = DpopProofVerifier.new(
      proof: dpop_proof,
      http_method: 'POST',
      http_url: api_openid_connect_introspect_url,
      access_token: token.presence,
    ).call
    if result.success?
      @proof_thumbprint = result.thumbprint
    else
      fail_with(:dpop_proof, 'invalid_dpop_proof', result.error_message, type: result.error_type)
    end
  end

  # Every condition under which the token still stands for a live delegation. Any failure is
  # reported the same way, as "not active".
  def token_active?
    entry.present? &&
      entry[:expires_at].to_i > Time.zone.now.to_i &&
      user.present? && !user.suspended? &&
      grant.present? && grant.valid_now? &&
      token_resource_server&.usable? == true &&
      token_service_provider&.delegation_service_provider? == true
  end

  # The audience may ask about its own token; the holder may ask about a token issued to it and
  # bound to the key it just proved possession of.
  def caller_entitled?
    case caller_type
    when :resource_server
      entry[:resource_server_id] == @caller_resource_server.id
    when :service_provider
      entry[:service_provider_id] == @caller_service_provider.id &&
        entry[:dpop_jkt].present? && entry[:dpop_jkt] == @proof_thumbprint
    else
      false
    end
  end

  def active_response
    case caller_type
    when :resource_server then resource_server_response
    when :service_provider then service_provider_response
    end
  end

  # RFC 7662 §2.2 members common to both callers, with the RFC 7800 `cnf` key binding when bound.
  def token_members
    members = {
      active: true,
      iss: root_url,
      aud: entry[:aud],
      scope: entry[:scope],
      client_id: token_service_provider.issuer,
      delegation_id: entry[:delegation_id],
      token_type: entry[:token_type],
      iat: entry[:issued_at],
      exp: entry[:expires_at],
    }
    members[:cnf] = { jkt: entry[:dpop_jkt] } if entry[:dpop_jkt].present?
    members
  end

  # The full response for the agency API: `sub` is the person's identifier for the agency, `act`
  # names the acting service provider (RFC 8693 §4.1), `jti` identifies this one token, `acr`,
  # `aal` and `auth_time` describe the sign-in the delegation rests on, and the identity claims
  # follow in userinfo shape. `session_live` tells the agency whether the whole bundle or only the
  # identifiers and email are present.
  def resource_server_response
    token_members
      .merge(
        sub: claims.agency_sub,
        act: { sub: token_service_provider.issuer },
        jti: DelegatedTokenStore.digest(token),
        acr: claims.acr,
        aal: claims.aal_acr,
        auth_time: auth_time,
        session_live: claims.session_live?,
      )
      .merge(claims.agency_claims)
  end

  # The limited response for the service provider: the token's status and the person as the
  # service provider's own sign-in already identifies them, plus whatever the application chose
  # to share. No `act`, no `auth_time`, no assurance levels, no agency attributes.
  def service_provider_response
    token_members
      .merge(sub: service_provider_sub)
      .merge(claims.shared_with_service_provider)
      .compact
  end

  def claims
    @claims ||= DelegatedTokenClaims.new(
      user:,
      identity:,
      application: token_resource_server.service_provider,
      ial: entry[:ial],
      aal: entry[:aal],
      sp_rails_session_id: entry[:sp_rails_session_id],
    )
  end

  # When the person last authenticated to the service provider, the sign-in this delegation rests
  # on; the token's issuance time if the connection carries no such instant.
  def auth_time
    identity&.last_authenticated_at&.to_i || entry[:issued_at]
  end

  # The `sub` the service provider's own id_token and userinfo carry for this person.
  def service_provider_sub
    return nil if identity.nil?

    AgencyIdentityLinker.new(identity).link_identity.uuid
  end

  def claimed_resource_server_identifier
    @caller_resource_server&.identifier || @auth_result&.claimed_identifier
  end

  def extra_analytics_attributes
    {
      caller_type: caller_type.to_s,
      resource_server_identifier: claimed_resource_server_identifier,
      service_provider_issuer: @caller_service_provider&.issuer,
      active: @success ? @active == true : nil,
      error_code:,
      integration_errors:,
    }
  end

  def integration_error_event
    :oidc_introspection_request
  end

  # Either kind of caller may be the misconfigured one: the API by its identifier, the service
  # provider by its issuer.
  def integration_error_issuer
    claimed_resource_server_identifier || @caller_service_provider&.issuer
  end

  def integration_exists?(identifier)
    @caller_resource_server.present? || @caller_service_provider.present? ||
      TokenExchangeResourceServer.exists?(identifier:)
  end
end
