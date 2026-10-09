# frozen_string_literal: true

# RFC 8693 (OAuth 2.0 Token Exchange).
#
# A subject_token (an existing Login.gov access token issued to a service provider approved for
# delegation) is exchanged for a freshly minted access token bound to one of the user's approved
# applications, for the SAME user, reusing the service provider's live Rails session so lifetimes
# match.
#
# The exchange only ever mints when the user approved the application for this service provider
# (TokenExchangeGrant), and only for applications that accept the service provider.
#
# The exchange only ever FORWARDS the IAL the service provider's token was actually asserted at;
# it never elevates. There is no step-up: the service provider must authenticate the user at
# IAL2 up front, so every downstream exchange is step-down-or-equal. A token asserted below IAL2
# cannot mint anything.
#
# The minted identity's scope is intersected with the application's own allowed attributes (its
# onboarding attribute bundle), so a token for the application never carries PII the service
# provider held but the application was not itself authorized for.
class OpenidConnectTokenExchangeForm
  include ActiveModel::Model

  TOKEN_EXCHANGE_GRANT_TYPE = 'urn:ietf:params:oauth:grant-type:token-exchange'
  ACCESS_TOKEN_TYPE = 'urn:ietf:params:oauth:token-type:access_token'

  # Maps an internal validation error type to an RFC 6749/8693 error code and
  # the HTTP status the endpoint should return. Order defines error precedence.
  #
  # Per RFC 8693 §2.2.2, a subject_token that is invalid for any reason or
  # unacceptable based on policy MUST yield `invalid_request`; an unusable
  # application (audience) SHOULD yield `invalid_application`.
  ERROR_CODES = {
    grant_type: ['unsupported_grant_type', :bad_request],
    subject_token_type: ['invalid_request', :bad_request],
    requested_token_type: ['invalid_request', :bad_request],
    invalid_subject_token: ['invalid_request', :bad_request],
    expired_subject_token: ['invalid_request', :bad_request],
    service_provider_not_approved: ['invalid_request', :bad_request],
    consent_required: ['invalid_request', :bad_request],
    ial_insufficient: ['invalid_request', :bad_request],
    self_exchange: ['invalid_target', :bad_request],
    unknown_application: ['invalid_target', :bad_request],
    application_refuses_service_provider: ['invalid_target', :bad_request],
    application_not_approved: ['invalid_target', :bad_request],
    application_connection_revoked: ['invalid_target', :bad_request],
    application_in_use: ['invalid_target', :bad_request],
  }.freeze

  # Translates SP-facing attribute_bundle names (AttributeAsserter::VALID_ATTRIBUTES
  # vocabulary, as configured in the partner portal) to the OIDC claim names used
  # by OpenidConnectAttributeScoper::ATTRIBUTE_SCOPES_MAP. Any of the address
  # component names entitles the application to the composite `address` claim.
  BUNDLE_ATTRIBUTE_TO_CLAIM = {
    'first_name' => 'given_name',
    'last_name' => 'family_name',
    'dob' => 'birthdate',
    'ssn' => 'social_security_number',
    'address1' => 'address',
    'address2' => 'address',
    'city' => 'address',
    'state' => 'address',
    'zipcode' => 'address',
  }.freeze

  ATTRS = %i[grant_type subject_token subject_token_type audience requested_token_type scope].freeze
  attr_reader(*ATTRS)

  validate :validate_grant_type
  validate :validate_subject_token_type
  validate :validate_requested_token_type
  validate :validate_subject_token
  validate :validate_service_provider_approved
  validate :validate_service_provider_consent
  validate :validate_application
  validate :validate_application_accepts_service_provider
  validate :validate_application_approved
  validate :validate_service_provider_ial
  validate :validate_application_connection

  # @param params [Hash] RFC 8693 request parameters
  # @param request [ActionDispatch::Request, nil] the inbound request, used only
  #   to attribute fraud signals (IP, user agent) to the APPLICATION service provider
  def initialize(params, request: nil)
    ATTRS.each { |key| instance_variable_set(:"@#{key}", params[key]) }
    @request = request
  end

  # Runs validations and mints the application identity exactly once. On a
  # successful mint the APPLICATION service provider -- the party receiving a
  # credential for this user -- is billed and receives the fraud signal, exactly
  # as if the user had completed a direct sign-in there. The service provider is neither
  # billed nor signalled for the application's return.
  def submit
    return @submit if defined?(@submit)

    @success = valid?
    if @success
      link_application_identity
      bill_application
      signal_application
    end

    @submit = FormResponse.new(
      success: @success,
      errors: errors,
      extra: {
        service_provider_issuer: service_provider_identity&.service_provider,
        application_issuer: audience,
        minted_ial: @link_application_identity&.ial,
        minted_scope: application_scope.presence,
        billable: @billable,
        fraud_signalled: @fraud_signalled,
      },
    )
  end

  # @return [Hash] RFC 8693 token-exchange response, or an RFC 6749 error hash.
  def response
    submit unless defined?(@success)
    return error_response unless @success

    id_token_builder = IdTokenBuilder.new(
      identity: @link_application_identity,
      code: @link_application_identity.session_uuid,
      actor: actor_claim,
    )

    {
      access_token: @link_application_identity.access_token,
      issued_token_type: ACCESS_TOKEN_TYPE,
      token_type: 'Bearer',
      expires_in: id_token_builder.ttl,
      scope: application_scope,
      id_token: id_token_builder.id_token,
      exchanged_from: service_provider_identity.service_provider,
    }
  end

  # HTTP status the controller should return for this exchange.
  def http_status
    submit unless defined?(@success)
    return :ok if @success
    _code, status = ERROR_CODES[first_error_type]
    status || :bad_request
  end

  private

  # Only the highest-precedence error is described. Joining every message
  # would let any access-token holder probe arbitrary audiences and learn which
  # SPs the user is connected to; see also #service_provider_authorized?.
  def error_response
    code, = ERROR_CODES[first_error_type]
    {
      error: code || 'invalid_request',
      error_description: first_error_message,
    }
  end

  def first_error_message
    type = first_error_type
    _attr, details = errors.details.find { |_a, ds| ds.any? { |d| d[:type] == type } }
    matched = details&.find { |d| d[:type] == type }
    matched ? matched[:error].to_s : errors.full_messages.first
  end

  # Every application-side validation is withheld until the presenting service provider has
  # cleared its own gates (allow-listed, user-consented, IAL2). Otherwise the
  # error surface for `audience` would let an arbitrary token holder enumerate
  # the user's SP connections, revocations and live sessions.
  def service_provider_authorized?
    return false if service_provider_identity.blank? || service_provider_identity.user.blank?
    service_provider_record&.active? &&
      service_provider_record.delegation_service_provider? &&
      service_provider_has_any_grant? &&
      OpenidConnectAttributeScoper.new(service_provider_identity.scope).delegation_requested? &&
      service_provider_asserted_ial2?
  end

  # The user has at least one active token-exchange grant for this service provider.
  # Which APPLICATIONS it covers is checked separately (#validate_application_approved),
  # after the service provider gates, so an unauthorized caller learns nothing about
  # which applications the user chose.
  def service_provider_has_any_grant?
    TokenExchangeGrant.live.exists?(
      user: service_provider_identity.user,
      service_provider_issuer: service_provider_identity.service_provider,
    )
  end

  def first_error_type
    present = errors.details.values.flatten.filter_map { |detail| detail[:type] }
    ERROR_CODES.keys.find { |type| present.include?(type) } || present.first
  end

  # Bills the APPLICATION service provider for the authentication it is receiving.
  # Mirrors BillableEventTrackable#create_sp_return_log for a direct sign-in:
  # same table, same IAL/profile attribution, issuer = the application. Billed once
  # per (user, application, service provider session) -- re-exchanging within the same session
  # only rotates the token and is not a second billable return, matching the
  # per-session dedupe of the direct path. The unique request_id index makes
  # this atomic across concurrent exchanges.
  def bill_application
    return if @link_application_identity.blank?

    attrs = sp_return_log_attributes
    begin
      SpReturnLog.create!(attrs.merge(request_id: billing_request_id, billable: true))
      @billable = true
    rescue ActiveRecord::RecordNotUnique
      # Already billed this (user, application, service provider session): record the repeat as
      # a non-billable return, exactly as BillableEventTrackable does for a
      # repeat visit within a session.
      SpReturnLog.create!(attrs.merge(request_id: SecureRandom.uuid, billable: false))
      @billable = false
    end
  end

  def sp_return_log_attributes
    ial = @link_application_identity.ial.to_i
    billed_ial = ial == Idp::Constants::IAL_MAX ? Idp::Constants::IAL2 : ial
    profile = billed_ial > 1 ? service_provider_identity.user.active_profile : nil

    {
      user: service_provider_identity.user,
      ial: billed_ial,
      issuer: application.issuer,
      profile_id: profile&.id,
      profile_verified_at: profile&.verified_at,
      profile_requested_issuer: profile&.initiating_service_provider_issuer,
      returned_at: Time.zone.now,
    }
  end

  # Deterministic per (user, application, service provider session) so the second exchange in
  # a session collides on the unique request_id index. A service provider identity with no
  # bound session cannot be deduped per session, so each mint is billed; the
  # session liveness check (#service_provider_session_live?) means this cannot occur for a
  # successfully validated exchange, but the fallback keeps billing correct
  # rather than collapsing every mint for that user into one.
  def billing_request_id
    return SecureRandom.uuid if service_provider_identity.rails_session_id.blank?

    Digest::SHA256.hexdigest(
      [
        'token-exchange',
        service_provider_identity.user.id,
        application.issuer,
        service_provider_identity.rails_session_id,
      ].join(':'),
    )
  end

  # Delivers the fraud / Attempts API signal to the APPLICATION service provider.
  # The application is the relying party that will act on this credential, so it --
  # not the service provider -- must see the login-completed event and the agency-scoped
  # user identifier. The tracker is built for the application explicitly; it
  # encrypts to the application's key and writes under the application's issuer, so
  # nothing about this return reaches the service provider's event stream.
  #
  # The inbound request is a server-to-server call from the service provider's backend,
  # so its IP, user agent and cookies describe the service provider's infrastructure, not
  # the user's device. They are deliberately NOT forwarded: attributing the
  # service provider's egress address to the user would poison the application's fraud model.
  # The raw IdP session id is likewise never released; the event's session
  # identifier is an opaque per-session hash.
  def signal_application
    return if @link_application_identity.blank?
    return unless application.attempts_api_enabled?

    AttemptsApi::Tracker.new(
      session_id: fraud_session_id,
      request: nil,
      user: service_provider_identity.user,
      sp: application,
      cookie_device_uuid: nil,
      sp_redirect_uri: nil,
      enabled_for_session: true,
    ).token_exchange_login_completed(
      service_provider_issuer: service_provider_identity.service_provider,
    )
    @fraud_signalled = true
  rescue StandardError => err
    NewRelic::Agent.notice_error(err)
    @fraud_signalled = false
  end

  # Opaque, stable within a service provider session, and not reversible to the IdP
  # session id (which must never leave the IdP).
  def fraud_session_id
    Digest::SHA256.hexdigest(
      ['token-exchange-session', service_provider_identity.rails_session_id].join(':'),
    )
  end

  def link_application_identity
    return @link_application_identity if defined?(@link_application_identity)

    @link_application_identity = ServiceProviderIdentity.transaction do
      identity = IdentityLinker.new(service_provider_identity.user, application)
        .link_identity(
          ial: service_provider_identity.ial,
          aal: service_provider_identity.aal,
          acr_values: service_provider_identity.acr_values,
          requested_aal_value: service_provider_identity.requested_aal_value,
          rails_session_id: service_provider_identity.rails_session_id,
          scope: application_scope,
          verified_attributes: application_verified_attributes,
          email_address_id: service_provider_identity.email_address_id,
          last_consented_at: Time.zone.now,
        )
      # IdentityLinker unions verified_attributes with whatever the (possibly
      # reused) row already held; force the exact narrowed set so a reused row
      # can never carry PII beyond the application's current bundle. Re-assert
      # email_address_id because the union may have included all_emails, which
      # clears it on save. The exchange never returns an authorization code, so
      # retire the one IdentityLinker minted rather than leave a redeemable code
      # behind. Both writes commit together.
      identity.update!(
        verified_attributes: application_verified_attributes,
        email_address_id: service_provider_identity.email_address_id,
        session_uuid: nil,
      )
      identity
    end
  end

  # Scope granted to the application. Safety is enforced in claim space, so the
  # candidates are every valid scope (not just the strings the service provider literally
  # requested): a scope is admitted only when EVERY claim it releases is one the
  # application may receive (see #application_allowed_claims). This lets a service provider that
  # holds the umbrella `profile` grant the narrower `profile:name` to a
  # name-only application, while refusing `profile` itself (which would also release
  # birthdate). Further narrowed to any `scope` the client explicitly requested
  # (RFC 8693 §2.1). Never a superset of what the service provider holds or the application may
  # receive.
  def application_scope
    return @application_scope if defined?(@application_scope)
    return @application_scope = nil if service_provider_identity.blank? || application.blank?

    candidates = OpenidConnectAttributeScoper::VALID_SCOPES - %w[openid]
    if scope.present?
      candidates &= OpenidConnectAttributeScoper.new(scope).scopes
    end
    granted = candidates.select do |candidate|
      released = Array(OpenidConnectAttributeScoper::SCOPE_ATTRIBUTE_MAP[candidate]).map(&:to_s)
      released.present? && (released - application_allowed_claims).empty?
    end
    @application_scope = (%w[openid] + granted).uniq.join(' ')
  end

  # RFC 8693 §4.1 `act` claim: the exchange is delegation -- the service provider acts on
  # behalf of the subject at the application -- so the issued id_token names the
  # service provider as the current actor. This lets the application tell a delegated token
  # apart from a direct sign-in and apply policy accordingly.
  def actor_claim
    { sub: service_provider_identity.service_provider }
  end

  # OIDC claim names the application may receive: its onboarding attribute_bundle
  # (SP-facing names such as first_name/dob, translated to claim names)
  # intersected with the claims the service provider itself was verified for AND the
  # claims the service provider's own granted scope releases. All three bound the result:
  # the application never receives a claim its bundle omits, never one the service provider was
  # not verified for, and never one the service provider's scope did not authorize it to
  # hold (a stale verified_attributes entry cannot resurface via exchange).
  def application_allowed_claims
    return @application_allowed_claims if defined?(@application_allowed_claims)

    bundle_claims = Array(application.metadata[:attribute_bundle]).map do |attr|
      BUNDLE_ATTRIBUTE_TO_CLAIM.fetch(attr.to_s, attr.to_s)
    end
    held_claims = Array(service_provider_identity.verified_attributes).map(&:to_s)
    scoped_claims = OpenidConnectAttributeScoper.new(service_provider_identity.scope)
      .requested_attributes.map(&:to_s)
    @application_allowed_claims = bundle_claims & held_claims & scoped_claims
  end

  # verified_attributes stored on the minted identity, in OIDC claim-name space
  # (matching how every other identity row is written), and exactly the claims
  # the granted scope releases -- so the stored set mirrors the scope narrowing.
  def application_verified_attributes
    OpenidConnectAttributeScoper.new(application_scope).requested_attributes.map(&:to_s) &
      application_allowed_claims
  end

  def service_provider_identity
    return @service_provider_identity if defined?(@service_provider_identity)
    @service_provider_identity = ServiceProviderIdentity.find_by(access_token: subject_token) if
      db_safe?(subject_token)
  end

  def service_provider_record
    return @service_provider_record if defined?(@service_provider_record)
    @service_provider_record =
      if service_provider_identity&.service_provider.present?
        ServiceProvider.find_by(issuer: service_provider_identity.service_provider)
      end
  end

  def service_provider_session_live?
    return false if service_provider_identity&.rails_session_id.blank?
    OutOfBandSessionAccessor.new(service_provider_identity.rails_session_id).ttl.to_i.positive?
  end

  def application
    return @application if defined?(@application)
    @application = ServiceProvider.find_by(issuer: audience) if db_safe?(audience)
  end

  # A null byte in a lookup value makes the PG adapter raise before validation
  # can reject it; treat such input as simply absent.
  def db_safe?(value)
    value.present? && !value.include?("\x00")
  end

  def validate_grant_type
    return if grant_type == TOKEN_EXCHANGE_GRANT_TYPE
    errors.add(:grant_type, 'unsupported_grant_type', type: :grant_type)
  end

  def validate_subject_token_type
    return if subject_token_type == ACCESS_TOKEN_TYPE
    errors.add(:subject_token_type, 'invalid_subject_token_type', type: :subject_token_type)
  end

  # `requested_token_type` is OPTIONAL (RFC 8693 §2.1). When omitted the issued
  # type is at our discretion (an access token). When supplied it must name a
  # type we can actually issue; we only issue access tokens.
  def validate_requested_token_type
    return if requested_token_type.blank? || requested_token_type == ACCESS_TOKEN_TYPE
    errors.add(
      :requested_token_type, 'unsupported_requested_token_type',
      type: :requested_token_type
    )
  end

  def validate_subject_token
    return errors.add(:subject_token, 'invalid_subject_token', type: :invalid_subject_token) if
      service_provider_identity.blank? || service_provider_identity.user.blank?

    unless service_provider_session_live?
      errors.add(:subject_token, 'expired_subject_token', type: :expired_subject_token)
    end
  end

  # The service provider SP must be configured (onboarded) as a token-exchange service provider and
  # still be an active SP. This is the login-controlled capability gate,
  # independent of the service provider's own signed application manifest.
  def validate_service_provider_approved
    return if service_provider_identity.blank? || service_provider_identity.user.blank?
    return if service_provider_record&.active? &&
              service_provider_record.delegation_service_provider?
    errors.add(
      :subject_token, 'service_provider_not_approved',
      type: :service_provider_not_approved
    )
  end

  # The user must have granted the service provider a token-exchange grant, AND the
  # subject token being presented must itself have been issued with the
  # `token_exchange` scope. Checking the presented token's scope (not just the
  # stored grant) means a later service provider authorization that dropped the scope
  # cannot reuse an earlier grant -- the consent travels with the grant it was
  # given for.
  def validate_service_provider_consent
    return if service_provider_identity.blank? || service_provider_identity.user.blank?
    return if service_provider_has_any_grant? &&
              OpenidConnectAttributeScoper.new(service_provider_identity.scope)
                .delegation_requested?
    errors.add(:subject_token, 'consent_required', type: :consent_required)
  end

  # The user's grant must cover THIS application: either chosen explicitly, included
  # in an all-applications grant, or covered by an all-and-future grant. A application the
  # service provider added after an all-applications (non-future) grant is not covered.
  def validate_application_approved
    return unless service_provider_authorized?
    return if application.blank?
    return if TokenExchangeGrant.authorizes?(
      user: service_provider_identity.user,
      service_provider_issuer: service_provider_identity.service_provider,
      application:,
    )
    errors.add(:audience, 'application_not_approved', type: :application_not_approved)
  end

  # The application must be a real, active SP that is itself entitled to identity
  # proofing (IAL2), and must not be the service provider itself. The exchange forwards an
  # IAL2 assertion and releases proofed attributes; an auth-only (IAL1) application
  # must never receive them, exactly as /authorize would refuse an IAL2 request
  # from such an SP. Which applications a service provider may reach is decided solely by the
  # applications' own opt-in (#validate_application_accepts_service_provider) and the user's grant
  # (#validate_application_approved); a service provider simply never requests a application it does
  # not support.
  def validate_application
    return unless service_provider_authorized?
    if audience.present? && audience == service_provider_identity.service_provider
      return errors.add(:audience, 'self_exchange', type: :self_exchange)
    end
    return if application&.delegation_application? &&
              application.identity_proofing_allowed?
    errors.add(:audience, 'unknown_application', type: :unknown_application)
  end

  # The application must itself opt in to being a token-exchange application for this
  # service provider, by allow-listing the service provider issuer in its own configuration (set in
  # the partner management portal). Neither login nor the service provider can force a
  # application to accept exchanged tokens it did not agree to.
  def validate_application_accepts_service_provider
    return unless service_provider_authorized?
    return if application.blank?
    return if application.accepts_delegation_from?(
      service_provider_identity.service_provider,
    )
    errors.add(
      :audience, 'application_refuses_service_provider',
      type: :application_refuses_service_provider
    )
  end

  # No step-up and no elevation: the exchange trusts the IAL that was actually
  # asserted on the service provider token (the stored `ial`), never a value re-derived
  # from SP defaults. Only a token asserted at IAL2 -- or IALMax (0), which is
  # IAL2 for an already-verified user -- may mint. An IAL1 (1) token never does.
  def validate_service_provider_ial
    return if service_provider_identity.blank? || service_provider_identity.user.blank?
    return if service_provider_asserted_ial2?
    errors.add(:subject_token, 'ial_insufficient', type: :ial_insufficient)
  end

  def service_provider_asserted_ial2?
    return false unless service_provider_identity.user.identity_verified?
    return false if service_provider_identity.ial.nil?
    ial = service_provider_identity.ial.to_i
    ial == Idp::Constants::IAL2 || ial == Idp::Constants::IAL_MAX
  end

  # Refuse to hijack a application identity that is already bound to a different,
  # still-live session, and refuse to silently revive a application connection the
  # user explicitly revoked (deleted_at set) -- re-establishing that requires a
  # fresh direct sign-in and consent at the application, not a delegated exchange.
  # Re-exchanging within the same service provider session (or reusing an identity whose
  # session is dead or was never bound to one) is fine and just rotates the
  # token.
  def validate_application_connection
    return unless service_provider_authorized?
    return if application.blank?
    existing = service_provider_identity.user.identities.find_by(service_provider: audience)
    return if existing.blank?
    if existing.deleted_at.present?
      return errors.add(
        :audience, 'application_connection_revoked',
        type: :application_connection_revoked
      )
    end
    return if existing.rails_session_id.blank?
    return if existing.rails_session_id == service_provider_identity.rails_session_id
    return unless OutOfBandSessionAccessor.new(existing.rails_session_id).ttl.to_i.positive?
    errors.add(:audience, 'application_in_use', type: :application_in_use)
  end
end
