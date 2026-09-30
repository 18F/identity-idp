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
    audience_not_allowed: ['invalid_target', :bad_request],
    unknown_target: ['invalid_target', :bad_request],
    target_forbids_broker: ['invalid_target', :bad_request],
    target_revoked: ['invalid_target', :bad_request],
    target_in_use: ['invalid_target', :bad_request],
  }.freeze

  # Translates SP-facing attribute_bundle names to OIDC claim names used by
  # OpenidConnectAttributeScoper::ATTRIBUTE_SCOPES_MAP.
  BUNDLE_ATTRIBUTE_TO_CLAIM = {
    'first_name' => 'given_name',
    'last_name' => 'family_name',
    'dob' => 'birthdate',
    'ssn' => 'social_security_number',
  }.freeze

  ATTRS = %i[grant_type subject_token subject_token_type audience requested_token_type scope].freeze
  attr_reader(*ATTRS)

  validate :validate_grant_type
  validate :validate_subject_token_type
  validate :validate_requested_token_type
  validate :validate_subject_token
  validate :validate_broker_allowed
  validate :validate_broker_consent
  validate :validate_audience_allowed
  validate :validate_target_service_provider
  validate :validate_target_allows_broker
  validate :validate_broker_ial
  validate :validate_target_not_in_use

  def initialize(params)
    ATTRS.each { |key| instance_variable_set(:"@#{key}", params[key]) }
  end

  # Runs validations and mints the target identity exactly once.
  def submit
    @success = valid?
    link_target_identity if @success

    FormResponse.new(
      success: @success,
      errors: errors,
      extra: {
        broker_issuer: broker_identity&.service_provider,
        target_issuer: audience,
        minted_ial: @link_target_identity&.ial,
        minted_scope: target_scope.presence,
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

  def error_response
    code, = ERROR_CODES[first_error_type]
    {
      error: code || 'invalid_request',
      error_description: errors.full_messages.join(' '),
    }
  end

  def first_error_type
    present = errors.details.values.flatten.filter_map { |detail| detail[:type] }
    ERROR_CODES.keys.find { |type| present.include?(type) } || present.first
  end

  def link_target_identity
    return @link_target_identity if defined?(@link_target_identity)

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
    # revived) row already held; force the exact narrowed set so a reused row
    # can never carry PII beyond the target SP's current bundle. The exchange
    # never returns an authorization code, so retire the one IdentityLinker
    # minted rather than leave a redeemable code behind.
    identity.update!(verified_attributes: target_verified_attributes, session_uuid: nil)
    @link_target_identity = identity
  end

  # Scope granted to the target. A scope is admitted only when EVERY claim it
  # releases is one the target may receive (see #target_allowed_claims); this
  # is what stops an umbrella scope such as `profile` from releasing birthdate
  # to a target whose bundle only names first_name. Further narrowed to any
  # `scope` the client explicitly requested (RFC 8693 §2.1). Never a superset.
  def target_scope
    return @target_scope if defined?(@target_scope)
    return @target_scope = nil if broker_identity.blank? || target_service_provider.blank?

    broker_scopes = OpenidConnectAttributeScoper.new(broker_identity.scope).scopes
    candidates = broker_scopes
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
  # intersected with the claims the broker itself was verified for. Both sides
  # bound the result; the target never receives a claim its bundle omits, and
  # never one the broker was not itself authorized to hold.
  def target_allowed_claims
    return @target_allowed_claims if defined?(@target_allowed_claims)

    bundle_claims = Array(target_service_provider.metadata[:attribute_bundle]).map do |attr|
      BUNDLE_ATTRIBUTE_TO_CLAIM.fetch(attr.to_s, attr.to_s)
    end
    held_claims = Array(broker_identity.verified_attributes).map(&:to_s)
    @target_allowed_claims = bundle_claims & held_claims
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
      subject_token.present?
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
    @target_service_provider = ServiceProvider.find_by(issuer: audience) if audience.present?
  end

  def allowed_audiences
    return [] if broker_identity.blank?
    TokenExchangeManifest.allowed_targets(broker_identity.service_provider)
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

  # The user must have granted the broker the token-exchange consent, AND the
  # subject token being presented must itself have been issued with the
  # `token_exchange` scope. Checking the presented token's scope (not just the
  # stored consent timestamp) means a later broker authorization that dropped
  # the scope cannot reuse an earlier consent -- the consent travels with the
  # grant it was given for.
  def validate_broker_consent
    return if broker_identity.blank? || broker_identity.user.blank?
    return if broker_identity.token_exchange_consented? &&
              OpenidConnectAttributeScoper.new(broker_identity.scope).token_exchange_requested?
    errors.add(:subject_token, 'consent_required', type: :consent_required)
  end

  def validate_audience_allowed
    return if broker_identity.blank?
    return if allowed_audiences.include?(audience)
    errors.add(:audience, 'audience_not_allowed', type: :audience_not_allowed)
  end

  # The target must be a real, active SP that is itself entitled to identity
  # proofing (IAL2). The exchange forwards an IAL2 assertion and releases
  # proofed attributes; an auth-only (IAL1) target must never receive them,
  # exactly as /authorize would refuse an IAL2 request from such an SP.
  def validate_target_service_provider
    return if audience.blank?
    return if target_service_provider&.active? &&
              target_service_provider.identity_proofing_allowed?
    errors.add(:audience, 'unknown_target', type: :unknown_target)
  end

  # The target SP must itself opt in to being a token-exchange target for this
  # broker, by allow-listing the broker issuer in its own configuration (set in
  # the partner management portal). Neither login nor the broker can force a
  # target to accept exchanged tokens it did not agree to.
  def validate_target_allows_broker
    return if broker_identity.blank? || target_service_provider.blank?
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
    return if broker_identity.blank? || target_service_provider.blank?
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
