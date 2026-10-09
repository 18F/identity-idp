# frozen_string_literal: true

# How a service provider is identified and authenticated at the delegated-access endpoints (token
# exchange, refresh and revocation), by the client type fixed at onboarding:
#
# * A confidential service provider authenticates with a `private_key_jwt` client assertion
#   (RFC 7523) signed with a key on its record, with `aud` naming the endpoint being called.
# * A public service provider (PKCE, no secret; its tokens live in the person's browser) only
#   names itself here, by `client_id`, and is authenticated by the DPoP proof (RFC 9449) it
#   presents with its token, which the including form verifies against the key that token is
#   bound to.
#
# The two credentials are not interchangeable: the record says which kind of client this is, and
# the other kind's credential is refused. Approval for delegated access is a property of the
# client, so it is checked here too. Every failure is `invalid_client` (RFC 6749 §5.2).
#
# The including form provides the `client_assertion`, `client_assertion_type` and `client_id`
# readers, a `client_assertion_audience` (the absolute URL of the endpoint) and `fail_with`.
module DelegatedAccessClientHandling
  extend ActiveSupport::Concern

  CLIENT_ASSERTION_TYPE = OpenidConnectTokenForm::CLIENT_ASSERTION_TYPE

  included do
    attr_reader :service_provider, :client_type
  end

  def public_client?
    client_type == 'public'
  end

  # The issuer the caller claimed, authenticated or not, so failures can be attributed.
  def claimed_issuer
    service_provider&.issuer || @auth_result&.claimed_identifier || client_id.presence
  end

  private

  def validate_client
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
      client_assertion:, audience: client_assertion_audience, key_source: :service_provider,
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
end
