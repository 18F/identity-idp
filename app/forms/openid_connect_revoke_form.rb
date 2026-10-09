# frozen_string_literal: true

# RFC 7009 token revocation for delegated access: a service provider ends its access early, when
# the person's task is done, by presenting a token it holds.
#
# The caller is identified by its client type (DelegatedAccessClientHandling): a confidential
# service provider by its client assertion with `aud` naming this endpoint, a public one by
# `client_id` and a DPoP proof (RFC 9449 §4.3) for this endpoint carrying `ath` over the presented
# token. A public client has no secret, so the proof is what ties the request to the token: a
# party that holds a copy of a token but not the key it is bound to cannot end it.
#
# What is acted on depends on what was presented:
#
# * A refresh token of this client's: the whole family is revoked, so the access token issued
#   with it and every one that followed stop working, and no refresh can mint another.
# * A delegated access token of this client's: that token alone is removed, and its issuance
#   record is marked revoked. Its family is untouched.
# * The access token of this client's own sign-in: accepted and not acted on. Ending the sign-in
#   is the logout flow's job; this endpoint ends delegated access only.
# * Anything else (unknown, another client's, already revoked, bound to another key): not acted
#   on.
#
# Once the caller has authenticated the answer is HTTP 200 with an empty JSON object in every one
# of those cases (RFC 7009 §2.2): revocation is idempotent, and the endpoint must not confirm
# whether a token exists or whose it is. `token_type_hint` only says which lookup to try first
# (§2.1); a wrong hint is not an error.
#
# Errors (RFC 7009 §2.2.1, RFC 6749 §5.2, RFC 9449 §5): `invalid_client` for a caller that does
# not authenticate or is not approved for delegation, `invalid_request` for a missing `token`,
# `invalid_dpop_proof` for a public client's proof that is missing or fails verification.
class OpenidConnectRevokeForm
  include ActiveModel::Model
  include ActionView::Helpers::TranslationHelper
  include Rails.application.routes.url_helpers
  include DelegatedAccessClientHandling

  REFRESH_TOKEN_HINT = 'refresh_token'
  ACCESS_TOKEN_HINT = 'access_token'

  ATTRS = %i[client_assertion client_assertion_type client_id dpop_proof token token_type_hint]
    .freeze

  attr_reader(*ATTRS)

  validate :validate_client
  validate :validate_token_present
  validate :validate_public_client_proof

  def initialize(params)
    ATTRS.each do |key|
      instance_variable_set(:"@#{key}", params[key])
    end
  end

  def submit
    @success = valid?
    @revoked = revoke! if @success
    FormResponse.new(success: @success, errors:, extra: extra_analytics_attributes)
  end

  # RFC 7009 §2.2: an empty body on success. A client that fails to authenticate is answered
  # with 401 as RFC 6749 §5.2 allows for `invalid_client`; every other error is 400.
  def http_status
    return :ok if @success

    error_code == 'invalid_client' ? :unauthorized : :bad_request
  end

  def response
    return {} if @success

    { error: error_code, error_description: errors.map(&:message).join(' ') }
  end

  def url_options
    {}
  end

  private

  attr_reader :error_code, :proof_thumbprint

  # Records an error under the RFC code the service provider should act on. Only the first code
  # is reported, since later checks are skipped once one fails.
  def fail_with(attribute, code, message, type:)
    @error_code ||= code
    errors.add(attribute, message, type:)
  end

  def client_assertion_audience
    api_openid_connect_revoke_url
  end

  def validate_token_present
    return if errors.any?
    return if token.present? && token.exclude?("\x00")

    fail_with(
      :token, 'invalid_request', t('openid_connect.revoke.errors.token_missing'),
      type: :token_missing
    )
  end

  # A public client's proof is for POST to this endpoint and carries `ath` over the presented
  # token (RFC 9449 §4.3). Which key it must be signed by is not known until the token is looked
  # up, so the proof is verified on its own terms here and its key is compared with the token's
  # binding in #revoke!; a token bound to another key is simply not acted on.
  def validate_public_client_proof
    return if errors.any? || !public_client?

    result = DpopProofVerifier.new(
      proof: dpop_proof,
      http_method: 'POST',
      http_url: api_openid_connect_revoke_url,
      access_token: token,
    ).call
    if result.success?
      @proof_thumbprint = result.thumbprint
      return
    end

    fail_with(:dpop_proof, 'invalid_dpop_proof', result.error_message, type: result.error_type)
  end

  # Tries the lookups in the order the hint suggests and acts on the first that finds this
  # client's token.
  # @return ["refresh_token", "access_token", "none"] what was acted on
  def revoke!
    lookups = [method(:revoke_refresh_family), method(:revoke_access_token)]
    lookups.reverse! if token_type_hint == ACCESS_TOKEN_HINT
    lookups.each do |lookup|
      outcome = lookup.call
      return outcome if outcome
    end
    'none'
  end

  # A refresh token of this client's, bound to the presenting key when the family is bound, ends
  # its whole family. A family that already ended is left as it is.
  def revoke_refresh_family
    row = TokenExchangeRefreshToken.lookup(token)
    return nil unless row && owned?(row.service_provider_id, row.dpop_jkt)
    return REFRESH_TOKEN_HINT if row.revoked?

    TokenExchangeRefreshToken.revoke_family!(row.family_id, reason: 'client_revoked')
    REFRESH_TOKEN_HINT
  end

  # A live delegated access token of this client's is removed and its issuance record marked
  # revoked; nothing else in its family changes.
  def revoke_access_token
    live = DelegatedTokenStore.read(token)
    return nil unless live && owned?(live[:service_provider_id], live[:dpop_jkt])

    now = Time.zone.now
    DelegatedTokenStore.revoke_token(token)
    TokenExchangeToken.where(id: live[:issuance_id], revoked_at: nil)
      .find_each { |issued| issued.revoke!(reason: 'client_revoked', now:) }
    ACCESS_TOKEN_HINT
  end

  # The token is this client's and, for a public client, bound to the key that signed the proof.
  def owned?(owner_service_provider_id, bound_thumbprint)
    return false unless owner_service_provider_id == service_provider.id
    return true unless public_client?

    bound_thumbprint.present? && bound_thumbprint == proof_thumbprint
  end

  def extra_analytics_attributes
    {
      service_provider_issuer: claimed_issuer,
      client_type:,
      token_type_hint: token_type_hint.presence,
      revoked: @revoked,
      error_code:,
      integration_errors:,
    }
  end

  def integration_errors
    return nil if @success || claimed_issuer.blank?

    {
      error_details: errors.full_messages,
      error_types: errors.attribute_names,
      event: :oidc_revoke_request,
      integration_exists: service_provider.present? ||
        ServiceProvider.exists?(issuer: claimed_issuer),
      request_issuer: claimed_issuer,
    }
  end
end
