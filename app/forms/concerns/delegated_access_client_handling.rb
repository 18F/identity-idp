# frozen_string_literal: true

# How a caller is identified and authenticated at the delegated-access endpoints (token exchange,
# refresh, revocation and introspection), by the client type fixed at onboarding:
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
# The module also carries what every one of these forms does the same way: it records each
# failure under the RFC error code the service provider should act on (#fail_with), answers a
# failure with the RFC 6749 §5.2 error object (#error_response), refuses PKCE as a substitute for
# a client credential (#validate_code_verifier_absent) and describes a failed request for the
# integration-errors event partner support reads (#integration_errors).
#
# The including form provides the `client_assertion`, `client_assertion_type` and `client_id`
# readers, a `client_assertion_audience` (the absolute URL of the endpoint), an
# `integration_error_event` naming the request kind, and sets `@success` when it submits. A form
# that serves agency APIs rather than service providers overrides #client_key_source and
# #confidential_client_authenticated, so the one client-assertion check verifies against the
# API's registered keys and hands it the API's record.
module DelegatedAccessClientHandling
  extend ActiveSupport::Concern
  # The forms build the absolute URL of the endpoint they serve, for client assertion audiences
  # and proof checks; the helpers come with this module so each form need not include them.
  include Rails.application.routes.url_helpers

  CLIENT_ASSERTION_TYPE = OpenidConnectTokenForm::CLIENT_ASSERTION_TYPE

  included do
    attr_reader :service_provider, :client_type, :error_code
  end

  def public_client?
    client_type == 'public'
  end

  # The issuer the caller claimed, authenticated or not, so failures can be attributed.
  def claimed_issuer
    service_provider&.issuer || @auth_result&.claimed_identifier || client_id.presence
  end

  # The RFC 6749 §5.2 error object: the first error code recorded and every message.
  def error_response
    { error: error_code, error_description: errors.map(&:message).join(' ') }
  end

  def url_options
    {}
  end

  private

  # Records an error under the RFC code the service provider should act on. Only the first code
  # is reported, since later checks are skipped once one fails. Returns false so a check can
  # record the failure and answer "no" in one statement.
  def fail_with(attribute, code, message, type:)
    @error_code ||= code
    errors.add(attribute, message, type:)
    false
  end

  # PKCE never substitutes for a client credential on these grants: a confidential client is
  # authenticated by its client assertion and a public client by the proof it presents.
  def validate_code_verifier_absent
    return if code_verifier.blank?

    fail_with(
      :code_verifier, 'invalid_request',
      t('openid_connect.token.errors.code_verifier_not_allowed'),
      type: :code_verifier_not_allowed
    )
  end

  # What the integration-errors event reports for a failed request from a caller that named
  # itself, so partner support can see which integration sent what; nil otherwise.
  def integration_errors
    issuer = integration_error_issuer
    return nil if @success || issuer.blank?

    {
      error_details: errors.full_messages,
      error_types: errors.attribute_names,
      event: integration_error_event,
      integration_exists: integration_exists?(issuer),
      request_issuer: issuer,
    }
  end

  # The identifier the integration-errors event attributes a failed request to.
  def integration_error_issuer
    claimed_issuer
  end

  # Whether that identifier names a registered integration, so support can tell a misconfigured
  # partner from an unknown caller.
  def integration_exists?(issuer)
    service_provider.present? || ServiceProvider.exists?(issuer:)
  end

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
      client_assertion:, audience: client_assertion_audience, key_source: client_key_source,
    ).call
    unless @auth_result.success?
      return fail_with(
        :client_assertion, 'invalid_client', @auth_result.error_message,
        type: @auth_result.error_type
      )
    end

    confidential_client_authenticated(@auth_result.record)
  end

  # Whose registered keys verify a client assertion at this endpoint: service providers, unless
  # the form serves agency APIs.
  def client_key_source
    :service_provider
  end

  # The service provider whose assertion verified. A public client has no secret to sign with; a
  # client assertion from one is a client presenting the wrong kind of credential, not an
  # authenticated public client.
  # @param record [ServiceProvider]
  def confidential_client_authenticated(record)
    if record.pkce == true
      return fail_with(
        :client_assertion, 'invalid_client',
        t('openid_connect.token.errors.client_authentication_required'),
        type: :client_type_mismatch
      )
    end

    @service_provider = record
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
