# frozen_string_literal: true

# Handles `grant_type=refresh_token` at the token endpoint (RFC 6749 §6) for delegated-access
# families, the only refresh tokens Login.gov issues. A refresh mints the next access token of the
# family (same API, same scope, same approval and delegation id, same key binding) and rotates the
# refresh token, so the service provider can keep acting for the person after the sign-in that
# started the delegation has ended, until the family's absolute end.
#
# The caller is identified by its client type (DelegatedAccessClientHandling): a confidential
# service provider by its client assertion, a public one by `client_id` and a DPoP proof
# (RFC 9449 §4.3) signed by the key the family is bound to. The proof carries no `ath`: a refresh
# token is not an access token (§4.3 item 12 applies to access tokens only).
#
# Rotation is what makes a long-lived refresh token safe to hold: every refresh token can be used
# exactly once. Presenting one that was already used means either the service provider replayed
# it or someone else holds a copy, and in both cases the whole family is revoked (RFC 9700
# §4.14.2) so a stolen token costs its holder the access instead of extending it. Rotation runs
# under a row lock on the presented token so two concurrent refreshes cannot both succeed.
#
# Error codes (RFC 6749 §5.2, RFC 9449 §5):
#
# * `invalid_client`      - no or wrong client credentials, or a client not approved for delegation
# * `invalid_request`     - a `resource` parameter (the audience is fixed by the family; a service
#                           provider that wants another API exchanges again), PKCE offered, or no
#                           refresh token
# * `invalid_grant`       - the refresh token is unknown, another client's, spent, revoked, or its
#                           family has ended or its approval no longer stands
# * `invalid_scope`       - `scope` was given and is not exactly the family's scope
# * `invalid_dpop_proof`  - a public client's proof is missing or fails verification
class OpenidConnectRefreshTokenForm
  include ActiveModel::Model
  include ActionView::Helpers::TranslationHelper
  include DelegatedAccessClientHandling

  GRANT_TYPE = 'refresh_token'
  ACCESS_TOKEN_TYPE = OpenidConnectTokenExchangeForm::ACCESS_TOKEN_TYPE

  ATTRS = %i[
    client_assertion
    client_assertion_type
    client_id
    code_verifier
    dpop_proof
    refresh_token
    resource
    scope
  ].freeze

  attr_reader(*ATTRS)

  validate :validate_code_verifier_absent
  validate :validate_client
  validate :validate_request_shape
  validate :validate_public_client_proof
  validate :validate_refresh_token

  def initialize(params)
    ATTRS.each do |key|
      instance_variable_set(:"@#{key}", params[key])
    end
  end

  def submit
    @success = valid? && rotate_and_mint!
    FormResponse.new(success: @success, errors:, extra: extra_analytics_attributes)
  end

  # The same shape as the exchange response, so a service provider handles both alike. Both
  # lifetimes are counted from the instant the new tokens were created.
  def response
    if @success
      {
        access_token: @access_token,
        issued_token_type: ACCESS_TOKEN_TYPE,
        token_type: @issued.token_type,
        expires_in: @issued.lifetime_seconds,
        scope: @issued.scope,
        refresh_token: @new_refresh_token,
        refresh_token_expires_in: @next.seconds_until_family_end(now: @issued.issued_at),
      }
    else
      error_response
    end
  end

  # Whether this request presented an already-spent refresh token and ended its family. False
  # when the family had already been ended by an earlier replay or by a revocation, so one theft
  # is reported once.
  def reuse_detected?
    @reuse_detected == true
  end

  private

  attr_reader :presented, :proof_thumbprint

  def client_assertion_audience
    api_openid_connect_token_url
  end

  # A refresh keeps the audience of the exchange that started the family, so `resource` is
  # refused outright rather than ignored. The refresh token itself must be present.
  def validate_request_shape
    return if errors.any?

    if Array(resource).map(&:to_s).any?(&:present?)
      return fail_with(
        :resource, 'invalid_request',
        t('openid_connect.token.errors.resource_not_allowed_on_refresh'),
        type: :resource_not_allowed_on_refresh
      )
    end
    return if refresh_token.present? && refresh_token.exclude?("\x00")

    fail_with(
      :refresh_token, 'invalid_request',
      t('openid_connect.token.errors.refresh_token_missing'),
      type: :refresh_token_missing
    )
  end

  # A public client's proof is for POST to this endpoint with no `ath`, since no access token is
  # presented (RFC 9449 §4.3, §5). It is verified before the refresh token is looked up, so a
  # caller without a valid proof learns nothing about the token; which key it must be signed by
  # is known only once the family is found (#validate_refresh_token). Every failure is
  # `invalid_dpop_proof`, and nothing about the family changes.
  def validate_public_client_proof
    return if errors.any? || !public_client?

    result = DpopProofVerifier.new(
      proof: dpop_proof, http_method: 'POST', http_url: api_openid_connect_token_url,
    ).call
    if result.success?
      @proof_thumbprint = result.thumbprint
      return
    end

    fail_with(:dpop_proof, 'invalid_dpop_proof', result.error_message, type: result.error_type)
  end

  # The token must exist and belong to this client before anything else about it is decided, so
  # a client holding another client's token gets the same answer as for a random string and
  # cannot end the other client's family. A public client must also have signed its proof with
  # the key the family is bound to. `scope`, when given, must be exactly the family's: a refresh
  # can neither widen nor narrow what the exchange issued.
  def validate_refresh_token
    return if errors.any?

    @presented = TokenExchangeRefreshToken.lookup(refresh_token)
    if presented.nil? || presented.service_provider_id != service_provider.id
      @presented = nil
      return fail_with(
        :refresh_token, 'invalid_grant', t('openid_connect.token.errors.invalid_refresh_token'),
        type: :invalid_refresh_token
      )
    end
    if public_client? && presented.dpop_jkt != proof_thumbprint
      return fail_with(
        :dpop_proof, 'invalid_dpop_proof', t('openid_connect.token.errors.dpop_key_mismatch'),
        type: :dpop_key_mismatch
      )
    end
    return if scope.blank? || scope == presented.scope

    fail_with(
      :scope, 'invalid_scope', t('openid_connect.token.errors.refresh_scope_mismatch'),
      type: :refresh_scope_mismatch
    )
  end

  # Rotation runs with the presented row locked (SELECT ... FOR UPDATE), so of two concurrent
  # refreshes with the same token the second waits, then sees the row spent and is treated as a
  # reuse. The live access token is written to Redis only after the transaction committed, so a
  # token can never be live without its record.
  # @return [Boolean] whether a token was minted
  def rotate_and_mint!
    now = Time.zone.now
    outcome = TokenExchangeRefreshToken.transaction do
      @presented = TokenExchangeRefreshToken.lock.find(presented.id)
      presented.rotated? ? handle_reuse!(now) : rotate_locked!(now)
    end
    write_live_token! if outcome
    outcome
  end

  # With the row locked: the token must be unspent and unrevoked, the family must not have ended,
  # the approval must still stand, and the API must still be open to this client. An approval
  # that no longer stands ends the family, since no refresh could ever succeed under it again. An
  # API that is switched off, or an application that no longer lists this client, is only a
  # refusal: switching it back on restores the family.
  def rotate_locked!(now)
    return refuse_refresh_token if presented.revoked? || presented.family_ended?(now:)
    unless approval_stands?
      TokenExchangeRefreshToken.revoke_family!(
        presented.family_id, grant: presented.grant, reason: 'approval_lapsed', now:
      )
      return refuse_refresh_token
    end
    return refuse_refresh_token unless api_open_to_client?

    presented.update!(used_at: now, rotated_at: now)
    mint!(now)
    true
  end

  # The API, its application and the application's agency are active, and the application still
  # lists this client (or lists no one, accepting every approved client).
  def api_open_to_client?
    resource_server.usable? && application.accepts_delegation_from?(service_provider.issuer)
  end

  # The approval is live, the person has not been shown materially different content since, and
  # a remembered approval is still within its period. A single-authorization approval stands for
  # as long as its family does: the family was opened in the sign-in that gave it, and continued
  # access was never meant to depend on that sign-in staying open.
  def approval_stands?
    grant = presented.grant
    !grant.revoked? && grant.current_content? &&
      (!grant.remembered? || grant.remember_until.future?)
  end

  def refuse_refresh_token
    fail_with(
      :refresh_token, 'invalid_grant', t('openid_connect.token.errors.invalid_refresh_token'),
      type: :invalid_refresh_token
    )
  end

  # An already-spent token was presented: end the whole family and record the replay. A family
  # that was already ended (an earlier replay, or a revocation) is not ended or reported again.
  def handle_reuse!(now)
    presented.update!(used_at: now)
    unless presented.revoked?
      TokenExchangeRefreshToken.revoke_family!(
        presented.family_id, grant: presented.grant, reason: 'refresh_token_reuse', now:
      )
      @reuse_detected = true
      report_family_revoked(reason: 'refresh_token_reuse')
    end
    fail_with(
      :refresh_token, 'invalid_grant', t('openid_connect.token.errors.refresh_token_reused'),
      type: :refresh_token_reused
    )
  end

  # The notice to the agency that owns the API that this family has ended, and why, leaves from
  # here. Nothing is delivered from the token endpoint itself.
  def report_family_revoked(reason:); end

  # The next access token of the family and the next refresh token, copied from the family: same
  # API, scope, approval, delegation id, assurance levels and key binding. The new refresh token
  # carries the family's end unchanged.
  def mint!(now)
    previous = presented.token_exchange_token
    lifetime = TokenExchangeToken.lifetime_seconds_for(
      now:, resource_server:, family_expires_at: presented.expires_at,
    )
    @access_token = TokenExchangeToken.generate_token
    @new_refresh_token = TokenExchangeRefreshToken.generate_token

    @issued = TokenExchangeToken.create!(
      grant: presented.grant,
      resource_server:,
      service_provider:,
      user: presented.user,
      delegation_id: presented.grant.delegation_id,
      scope: presented.scope,
      ial: previous.ial,
      aal: previous.aal,
      refresh_family_id: presented.family_id,
      token_type: presented.key_bound? ? 'DPoP' : 'Bearer',
      token_format: 'oauth',
      dpop_jkt: presented.dpop_jkt,
      sp_rails_session_id: previous.sp_rails_session_id,
      issued_at: now,
      expires_at: now + lifetime.seconds,
    )
    @next = TokenExchangeRefreshToken.create!(
      token_digest: TokenExchangeRefreshToken.digest(@new_refresh_token),
      family_id: presented.family_id,
      grant: presented.grant,
      token_exchange_token: @issued,
      resource_server:,
      service_provider:,
      user: presented.user,
      scope: presented.scope,
      dpop_jkt: presented.dpop_jkt,
      expires_at: presented.expires_at,
    )
  end

  def write_live_token!
    DelegatedTokenStore.write(
      @access_token, @issued.live_attributes, ttl: @issued.lifetime_seconds
    )
  end

  def resource_server
    presented&.resource_server
  end

  def application
    resource_server&.service_provider
  end

  def extra_analytics_attributes
    {
      service_provider_issuer: claimed_issuer,
      resource_server_identifier: resource_server&.identifier,
      application_issuer: application&.issuer,
      client_type:,
      token_type: @issued&.token_type,
      family_id: presented&.family_id,
      reuse_detected: reuse_detected?,
      error_code:,
      integration_errors:,
    }
  end

  def integration_error_event
    :oidc_token_refresh_request
  end
end
