# frozen_string_literal: true

# RFC 8693 (OAuth 2.0 Token Exchange), browser-callable, no client secret.
#
# A subject_token (an existing login.gov access token issued to an allowlisted
# "broker" SP) is exchanged for a freshly minted access token bound to a target
# SP for the SAME user, reusing the broker's live Rails session so lifetimes
# match.
#
# The exchange only ever mints when the user granted the broker the
# token-exchange consent during proofing, and only for targets on the broker's
# signed manifest allowlist.
#
# The exchange only ever FORWARDS the IAL the broker token was actually asserted
# at -- it never elevates. There is no step-up: the broker must authenticate the
# user at IAL2 up front, so every downstream exchange is step-down-or-equal. A
# broker token asserted below IAL2 cannot mint anything.
#
# The minted identity's scope is intersected with the target SP's own allowed
# attributes (its onboarding attribute bundle), so a target token never carries
# PII the broker held but the target was not itself authorized for.
class OpenidConnectTokenExchangeForm
  include ActiveModel::Model

  TOKEN_EXCHANGE_GRANT_TYPE = 'urn:ietf:params:oauth:grant-type:token-exchange'
  ACCESS_TOKEN_TYPE = 'urn:ietf:params:oauth:token-type:access_token'

  # Maps an internal validation error type to an RFC 6749/8693 error code and
  # the HTTP status the endpoint should return. Order defines error precedence.
  #
  # Per RFC 8693 §2.2.2, a subject_token that is invalid for any reason or
  # unacceptable based on policy MUST yield `invalid_request`; an unusable
  # target (audience) SHOULD yield `invalid_target`.
  ERROR_CODES = {
    grant_type: ['unsupported_grant_type', :bad_request],
    subject_token_type: ['invalid_request', :bad_request],
    requested_token_type: ['invalid_request', :bad_request],
    invalid_subject_token: ['invalid_request', :bad_request],
    expired_subject_token: ['invalid_request', :bad_request],
    broker_not_allowed: ['invalid_request', :bad_request],
    consent_required: ['invalid_request', :bad_request],
    ial_insufficient: ['invalid_request', :bad_request],
    self_exchange: ['invalid_target', :bad_request],
    unknown_target: ['invalid_target', :bad_request],
    target_forbids_broker: ['invalid_target', :bad_request],
    target_not_granted: ['invalid_target', :bad_request],
    target_revoked: ['invalid_target', :bad_request],
    target_in_use: ['invalid_target', :bad_request],
  }.freeze

  # Translates SP-facing attribute_bundle names (AttributeAsserter::VALID_ATTRIBUTES
  # vocabulary, as configured in the partner portal) to the OIDC claim names used
  # by OpenidConnectAttributeScoper::ATTRIBUTE_SCOPES_MAP. Any of the address
  # component names entitles the target to the composite `address` claim.
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
  validate :validate_broker_allowed
  validate :validate_broker_consent
  validate :validate_target_service_provider
  validate :validate_target_allows_broker
  validate :validate_target_granted
  validate :validate_broker_ial
  validate :validate_target_not_in_use

  # @param params [Hash] RFC 8693 request parameters
  # @param request [ActionDispatch::Request, nil] the inbound request, used only
  #   to attribute fraud signals (IP, user agent) to the TARGET service provider
  def initialize(params, request: nil)
    ATTRS.each { |key| instance_variable_set(:"@#{key}", params[key]) }
    @request = request
  end

  # Runs validations and mints the target identity exactly once. On a
  # successful mint the TARGET service provider -- the party receiving a
  # credential for this user -- is billed and receives the fraud signal, exactly
  # as if the user had completed a direct sign-in there. The broker is neither
  # billed nor signalled for the target's return.
  def submit
    return @submit if defined?(@submit)

    @success = valid?
    if @success
      link_target_identity
      bill_target
      signal_target
    end

    @submit = FormResponse.new(
      success: @success,
      errors: errors,
      extra: {
        broker_issuer: broker_identity&.service_provider,
        target_issuer: audience,
        minted_ial: @link_target_identity&.ial,
        minted_scope: target_scope.presence,
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
      identity: @link_target_identity,
      code: @link_target_identity.session_uuid,
      actor: actor_claim,
    )

    {
      access_token: @link_target_identity.access_token,
      issued_token_type: ACCESS_TOKEN_TYPE,
      token_type: 'Bearer',
      expires_in: id_token_builder.ttl,
      scope: target_scope,
      id_token: id_token_builder.id_token,
      exchanged_from: broker_identity.service_provider,
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
  # SPs the user is connected to; see also #broker_authorized?.
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

  # Every target-side validation is withheld until the presenting broker has
  # cleared its own gates (allow-listed, user-consented, IAL2). Otherwise the
  # error surface for `audience` would let an arbitrary token holder enumerate
  # the user's SP connections, revocations and live sessions.
  def broker_authorized?
    return false if broker_identity.blank? || broker_identity.user.blank?
    broker_service_provider&.active? &&
      broker_service_provider.token_exchange_broker_allowed? &&
      broker_has_any_grant? &&
      OpenidConnectAttributeScoper.new(broker_identity.scope).token_exchange_requested? &&
      broker_asserted_ial2?
  end

  # The user has at least one active token-exchange grant for this broker.
  # Which TARGETS it covers is checked separately (#validate_target_granted),
  # after the broker gates, so an unauthorized caller learns nothing about
  # which applications the user chose.
  def broker_has_any_grant?
    TokenExchangeGrant.active.exists?(
      user: broker_identity.user, broker_issuer: broker_identity.service_provider,
    )
  end

  def first_error_type
    present = errors.details.values.flatten.filter_map { |detail| detail[:type] }
    ERROR_CODES.keys.find { |type| present.include?(type) } || present.first
  end

  # Bills the TARGET service provider for the authentication it is receiving.
  # Mirrors BillableEventTrackable#create_sp_return_log for a direct sign-in:
  # same table, same IAL/profile attribution, issuer = the target. Billed once
  # per (user, target, broker session) -- re-exchanging within the same session
  # only rotates the token and is not a second billable return, matching the
  # per-session dedupe of the direct path. The unique request_id index makes
  # this atomic across concurrent exchanges.
  def bill_target
    return if @link_target_identity.blank?

    attrs = sp_return_log_attributes
    begin
      SpReturnLog.create!(attrs.merge(request_id: billing_request_id, billable: true))
      @billable = true
    rescue ActiveRecord::RecordNotUnique
      # Already billed this (user, target, broker session): record the repeat as
      # a non-billable return, exactly as BillableEventTrackable does for a
      # repeat visit within a session.
      SpReturnLog.create!(attrs.merge(request_id: SecureRandom.uuid, billable: false))
      @billable = false
    end
  end

  def sp_return_log_attributes
    ial = @link_target_identity.ial.to_i
    billed_ial = ial == Idp::Constants::IAL_MAX ? Idp::Constants::IAL2 : ial
    profile = billed_ial > 1 ? broker_identity.user.active_profile : nil

    {
      user: broker_identity.user,
      ial: billed_ial,
      issuer: target_service_provider.issuer,
      profile_id: profile&.id,
      profile_verified_at: profile&.verified_at,
      profile_requested_issuer: profile&.initiating_service_provider_issuer,
      returned_at: Time.zone.now,
    }
  end

  # Deterministic per (user, target, broker session) so the second exchange in
  # a session collides on the unique request_id index. A broker identity with no
  # bound session cannot be deduped per session, so each mint is billed; the
  # session liveness check (#broker_session_live?) means this cannot occur for a
  # successfully validated exchange, but the fallback keeps billing correct
  # rather than collapsing every mint for that user into one.
  def billing_request_id
    return SecureRandom.uuid if broker_identity.rails_session_id.blank?

    Digest::SHA256.hexdigest(
      [
        'token-exchange',
        broker_identity.user.id,
        target_service_provider.issuer,
        broker_identity.rails_session_id,
      ].join(':'),
    )
  end

  # Delivers the fraud / Attempts API signal to the TARGET service provider.
  # The target is the relying party that will act on this credential, so it --
  # not the broker -- must see the login-completed event and the agency-scoped
  # user identifier. The tracker is built for the target SP explicitly; it
  # encrypts to the target's key and writes under the target's issuer, so
  # nothing about this return reaches the broker's event stream.
  #
  # The inbound request is a server-to-server call from the broker's backend,
  # so its IP, user agent and cookies describe the broker's infrastructure, not
  # the user's device. They are deliberately NOT forwarded: attributing the
  # broker's egress address to the user would poison the target's fraud model.
  # The raw IdP session id is likewise never released; the event's session
  # identifier is an opaque per-session hash.
  def signal_target
    return if @link_target_identity.blank?
    return unless target_service_provider.attempts_api_enabled?

    AttemptsApi::Tracker.new(
      session_id: fraud_session_id,
      request: nil,
      user: broker_identity.user,
      sp: target_service_provider,
      cookie_device_uuid: nil,
      sp_redirect_uri: nil,
      enabled_for_session: true,
    ).token_exchange_login_completed(broker_issuer: broker_identity.service_provider)
    @fraud_signalled = true
  rescue StandardError => err
    NewRelic::Agent.notice_error(err)
    @fraud_signalled = false
  end

  # Opaque, stable within a broker session, and not reversible to the IdP
  # session id (which must never leave the IdP).
  def fraud_session_id
    Digest::SHA256.hexdigest(
      ['token-exchange-session', broker_identity.rails_session_id].join(':'),
    )
  end

  def link_target_identity
    return @link_target_identity if defined?(@link_target_identity)

    @link_target_identity = ServiceProviderIdentity.transaction do
      identity = IdentityLinker.new(broker_identity.user, target_service_provider)
        .link_identity(
          ial: broker_identity.ial,
          aal: broker_identity.aal,
          acr_values: broker_identity.acr_values,
          requested_aal_value: broker_identity.requested_aal_value,
          rails_session_id: broker_identity.rails_session_id,
          scope: target_scope,
          verified_attributes: target_verified_attributes,
          email_address_id: broker_identity.email_address_id,
          last_consented_at: Time.zone.now,
        )
      # IdentityLinker unions verified_attributes with whatever the (possibly
      # reused) row already held; force the exact narrowed set so a reused row
      # can never carry PII beyond the target SP's current bundle. Re-assert
      # email_address_id because the union may have included all_emails, which
      # clears it on save. The exchange never returns an authorization code, so
      # retire the one IdentityLinker minted rather than leave a redeemable code
      # behind. Both writes commit together.
      identity.update!(
        verified_attributes: target_verified_attributes,
        email_address_id: broker_identity.email_address_id,
        session_uuid: nil,
      )
      identity
    end
  end

  # Scope granted to the target. Safety is enforced in claim space, so the
  # candidates are every valid scope (not just the strings the broker literally
  # requested): a scope is admitted only when EVERY claim it releases is one the
  # target may receive (see #target_allowed_claims). This lets a broker that
  # holds the umbrella `profile` grant the narrower `profile:name` to a
  # name-only target, while refusing `profile` itself (which would also release
  # birthdate). Further narrowed to any `scope` the client explicitly requested
  # (RFC 8693 §2.1). Never a superset of what the broker holds or the target may
  # receive.
  def target_scope
    return @target_scope if defined?(@target_scope)
    return @target_scope = nil if broker_identity.blank? || target_service_provider.blank?

    candidates = OpenidConnectAttributeScoper::VALID_SCOPES - %w[openid token_exchange]
    if scope.present?
      candidates &= OpenidConnectAttributeScoper.new(scope).scopes
    end
    granted = candidates.select do |candidate|
      released = Array(OpenidConnectAttributeScoper::SCOPE_ATTRIBUTE_MAP[candidate]).map(&:to_s)
      released.present? && (released - target_allowed_claims).empty?
    end
    @target_scope = (%w[openid] + granted).uniq.join(' ')
  end

  # RFC 8693 §4.1 `act` claim: the exchange is delegation -- the broker acts on
  # behalf of the subject at the target -- so the issued id_token names the
  # broker as the current actor. This lets the target tell a brokered token
  # apart from a direct sign-in and apply policy accordingly.
  def actor_claim
    { sub: broker_identity.service_provider }
  end

  # OIDC claim names the target may receive: its onboarding attribute_bundle
  # (SP-facing names such as first_name/dob, translated to claim names)
  # intersected with the claims the broker itself was verified for AND the
  # claims the broker's own granted scope releases. All three bound the result:
  # the target never receives a claim its bundle omits, never one the broker was
  # not verified for, and never one the broker's scope did not authorize it to
  # hold (a stale verified_attributes entry cannot resurface via exchange).
  def target_allowed_claims
    return @target_allowed_claims if defined?(@target_allowed_claims)

    bundle_claims = Array(target_service_provider.metadata[:attribute_bundle]).map do |attr|
      BUNDLE_ATTRIBUTE_TO_CLAIM.fetch(attr.to_s, attr.to_s)
    end
    held_claims = Array(broker_identity.verified_attributes).map(&:to_s)
    scoped_claims = OpenidConnectAttributeScoper.new(broker_identity.scope)
      .requested_attributes.map(&:to_s)
    @target_allowed_claims = bundle_claims & held_claims & scoped_claims
  end

  # verified_attributes stored on the minted identity, in OIDC claim-name space
  # (matching how every other identity row is written), and exactly the claims
  # the granted scope releases -- so the stored set mirrors the scope narrowing.
  def target_verified_attributes
    OpenidConnectAttributeScoper.new(target_scope).requested_attributes.map(&:to_s) &
      target_allowed_claims
  end

  def broker_identity
    return @broker_identity if defined?(@broker_identity)
    @broker_identity = ServiceProviderIdentity.find_by(access_token: subject_token) if
      db_safe?(subject_token)
  end

  def broker_service_provider
    return @broker_service_provider if defined?(@broker_service_provider)
    @broker_service_provider =
      if broker_identity&.service_provider.present?
        ServiceProvider.find_by(issuer: broker_identity.service_provider)
      end
  end

  def broker_session_live?
    return false if broker_identity&.rails_session_id.blank?
    OutOfBandSessionAccessor.new(broker_identity.rails_session_id).ttl.to_i.positive?
  end

  def target_service_provider
    return @target_service_provider if defined?(@target_service_provider)
    @target_service_provider = ServiceProvider.find_by(issuer: audience) if db_safe?(audience)
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
      broker_identity.blank? || broker_identity.user.blank?

    unless broker_session_live?
      errors.add(:subject_token, 'expired_subject_token', type: :expired_subject_token)
    end
  end

  # The broker SP must be configured (onboarded) as a token-exchange broker and
  # still be an active SP. This is the login-controlled capability gate,
  # independent of the broker's own signed target manifest.
  def validate_broker_allowed
    return if broker_identity.blank? || broker_identity.user.blank?
    return if broker_service_provider&.active? &&
              broker_service_provider.token_exchange_broker_allowed?
    errors.add(:subject_token, 'broker_not_allowed', type: :broker_not_allowed)
  end

  # The user must have granted the broker a token-exchange grant, AND the
  # subject token being presented must itself have been issued with the
  # `token_exchange` scope. Checking the presented token's scope (not just the
  # stored grant) means a later broker authorization that dropped the scope
  # cannot reuse an earlier grant -- the consent travels with the grant it was
  # given for.
  def validate_broker_consent
    return if broker_identity.blank? || broker_identity.user.blank?
    return if broker_has_any_grant? &&
              OpenidConnectAttributeScoper.new(broker_identity.scope).token_exchange_requested?
    errors.add(:subject_token, 'consent_required', type: :consent_required)
  end

  # The user's grant must cover THIS target: either chosen explicitly, included
  # in an all-targets grant, or covered by an all-and-future grant. A target the
  # broker added after an all-targets (non-future) grant is not covered.
  def validate_target_granted
    return unless broker_authorized?
    return if target_service_provider.blank?
    return if TokenExchangeGrant.authorizes?(
      user: broker_identity.user,
      broker_issuer: broker_identity.service_provider,
      target_issuer: audience,
    )
    errors.add(:audience, 'target_not_granted', type: :target_not_granted)
  end

  # The target must be a real, active SP that is itself entitled to identity
  # proofing (IAL2), and must not be the broker itself. The exchange forwards an
  # IAL2 assertion and releases proofed attributes; an auth-only (IAL1) target
  # must never receive them, exactly as /authorize would refuse an IAL2 request
  # from such an SP. Which targets a broker may reach is decided solely by the
  # targets' own opt-in (#validate_target_allows_broker) and the user's grant
  # (#validate_target_granted); a broker simply never requests a target it does
  # not support.
  def validate_target_service_provider
    return unless broker_authorized?
    if audience.present? && audience == broker_identity.service_provider
      return errors.add(:audience, 'self_exchange', type: :self_exchange)
    end
    return if target_service_provider&.active? &&
              target_service_provider.identity_proofing_allowed?
    errors.add(:audience, 'unknown_target', type: :unknown_target)
  end

  # The target SP must itself opt in to being a token-exchange target for this
  # broker, by allow-listing the broker issuer in its own configuration (set in
  # the partner management portal). Neither login nor the broker can force a
  # target to accept exchanged tokens it did not agree to.
  def validate_target_allows_broker
    return unless broker_authorized?
    return if target_service_provider.blank?
    return if target_service_provider.allows_token_exchange_broker?(
      broker_identity.service_provider,
    )
    errors.add(:audience, 'target_forbids_broker', type: :target_forbids_broker)
  end

  # No step-up and no elevation: the exchange trusts the IAL that was actually
  # asserted on the broker token (the stored `ial`), never a value re-derived
  # from SP defaults. Only a token asserted at IAL2 -- or IALMax (0), which is
  # IAL2 for an already-verified user -- may mint. An IAL1 (1) token never does.
  def validate_broker_ial
    return if broker_identity.blank? || broker_identity.user.blank?
    return if broker_asserted_ial2?
    errors.add(:subject_token, 'ial_insufficient', type: :ial_insufficient)
  end

  def broker_asserted_ial2?
    return false unless broker_identity.user.identity_verified?
    return false if broker_identity.ial.nil?
    ial = broker_identity.ial.to_i
    ial == Idp::Constants::IAL2 || ial == Idp::Constants::IAL_MAX
  end

  # Refuse to hijack a target identity that is already bound to a different,
  # still-live session, and refuse to silently revive a target connection the
  # user explicitly revoked (deleted_at set) -- re-establishing that requires a
  # fresh direct sign-in and consent at the target, not a brokered exchange.
  # Re-exchanging within the same broker session (or reusing an identity whose
  # session is dead or was never bound to one) is fine and just rotates the
  # token.
  def validate_target_not_in_use
    return unless broker_authorized?
    return if target_service_provider.blank?
    existing = broker_identity.user.identities.find_by(service_provider: audience)
    return if existing.blank?
    if existing.deleted_at.present?
      return errors.add(:audience, 'target_revoked', type: :target_revoked)
    end
    return if existing.rails_session_id.blank?
    return if existing.rails_session_id == broker_identity.rails_session_id
    return unless OutOfBandSessionAccessor.new(existing.rails_session_id).ttl.to_i.positive?
    errors.add(:audience, 'target_in_use', type: :target_in_use)
  end
end
