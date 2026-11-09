# frozen_string_literal: true

# The refresh token grant (RFC 6749 §6) for token exchange actors: trades a refresh token for a
# new subject token and the next refresh token in the family, with no new sign-in. Refresh tokens
# are bound to the same key as the subject token (RFC 9449 §5), so every request carries a proof
# from that key. The proof names no token (no `ath`), because a refresh token isn't presented to a
# resource.
#
# The person's Login.gov session isn't consulted. A family is limited instead by its own idle
# timeout, its absolute lifetime from the person's authentication, and revocation.
class OpenidConnectRefreshTokenForm
  include ActiveModel::Model

  GRANT_TYPE = 'refresh_token'

  ATTRS = %i[
    client_id
    grant_type
    refresh_token
    scope
    dpop_proof
    token_url
  ].freeze

  REQUIRED_ATTRS = %i[client_id grant_type refresh_token].freeze

  attr_reader(*ATTRS)

  validates(*REQUIRED_ATTRS, presence: true)

  # Ordered cheapest first. Reuse is checked after the proof, so a copy of a refresh token without
  # the key can't revoke the person's family.
  validate :validate_enabled
  validate :validate_actor, unless: :failed?
  validate :validate_refresh_token, unless: :failed?
  validate :validate_scope, unless: :failed?
  validate :validate_dpop_proof, unless: :failed?
  validate :validate_unused, unless: :failed?
  validate :validate_identity, unless: :failed?

  def initialize(params)
    ATTRS.each do |key|
      instance_variable_set(:"@#{key}", params[key])
    end
  end

  # Rotates the refresh token on success. Memoized so the controller can read the result and the
  # response without rotating twice.
  # @return [FormResponse]
  def submit
    return @submit if defined?(@submit)

    success = valid? && rotate
    @submit = FormResponse.new(success:, errors:, extra: extra_analytics_attributes)
  end

  def response
    return error_response unless submit.success?

    {
      access_token: subject_token.token,
      token_type: 'DPoP',
      expires_in: subject_token.expires_in,
      refresh_token: rotated.token,
      scope: stored_token.scope,
    }
  end

  # `invalid_client` is a client authentication failure, which RFC 6749 §5.2 answers with a 401.
  def http_status
    return :ok if submit.success?

    oauth_error == 'invalid_client' ? :unauthorized : :bad_request
  end

  private

  attr_reader :rotated, :subject_token

  def failed?
    errors.any?
  end

  def validate_enabled
    return if refresh_enabled?

    errors.add(:grant_type, :inclusion)
  end

  def refresh_enabled?
    IdentityConfig.store.token_exchange_enabled &&
      IdentityConfig.store.token_exchange_refresh_token_enabled
  end

  # The client is identified, not authenticated, as for any public client; the key binding is
  # what stops anyone else using its refresh tokens.
  def validate_actor
    return if actor&.token_exchange_actor? && actor.dpop_required?

    errors.add(:client_id, :invalid)
  end

  def validate_refresh_token
    if stored_token.blank? || stored_token.actor_issuer != client_id
      reject_refresh_token(:refresh_token_invalid)
    elsif stored_token.revoked?
      reject_refresh_token(:refresh_token_revoked)
    elsif stored_token.expired?
      reject_refresh_token(:refresh_token_expired)
    end
  end

  # A refresh can't change what the subject token may be exchanged for.
  def validate_scope
    return if scope.blank? || scope.split(' ').sort == stored_token.scope.to_s.split(' ').sort

    errors.add(:scope, :invalid)
  end

  def validate_dpop_proof
    return if dpop_result.success?

    dpop_error = dpop_result.errors[:proof].first
    errors.add(:dpop_proof, dpop_error, type: dpop_error.to_sym)
  end

  def validate_unused
    return unless stored_token.used?

    reuse_detected!
  end

  # The actor identity is gone if the person deleted their account or disconnected the actor.
  def validate_identity
    return if identity.present? && identity.deleted_at.nil? && !identity.user.suspended?

    reject_refresh_token(:refresh_token_identity_inactive)
  end

  # The subject token is minted first, so a failure minting it leaves the refresh token unused
  # and the actor can retry. If the rotation then loses a race, the subject token is never
  # returned and simply expires. The resource, scope and IAL come from the family, not the
  # identity, which a later sign-in from the actor overwrites.
  def rotate
    @subject_token = TokenExchange::SubjectTokenIssuer.issue(
      identity:,
      actor_return_log_id: stored_token.actor_return_log_id,
      resource: stored_token.resource,
      dpop_jkt: stored_token.dpop_jkt,
      scope: stored_token.scope,
      ial: stored_token.ial,
    )

    # A token another request rotated since validation is a reuse like any other.
    @rotated = TokenExchange::RefreshTokenIssuer.rotate(stored_token)
    return true if rotated.present?

    reuse_detected!
    false
  end

  def reuse_detected!
    @reuse_detected = true
    stored_token.revoke_family!(reason: 'reuse_detected')
    reject_refresh_token(:refresh_token_reused)
  end

  # As in DpopProofForm: the message is the machine-readable type, since another program reads it.
  def reject_refresh_token(type)
    errors.add(:refresh_token, type.to_s, type:)
  end

  def dpop_result
    @dpop_result ||= DpopProofForm.new(
      proof: dpop_proof,
      http_method: 'POST',
      http_url: token_url,
      expected_thumbprint: stored_token.dpop_jkt,
    ).submit
  end

  def actor
    return @actor if defined?(@actor)

    @actor = ServiceProvider.find_by(issuer: client_id)
  end

  def stored_token
    return @stored_token if defined?(@stored_token)

    @stored_token = TokenExchangeRefreshToken.for_token(refresh_token)
  end

  def identity
    return @identity if defined?(@identity)

    @identity = ServiceProviderIdentity.find_by(
      uuid: stored_token.identity_uuid,
      service_provider: stored_token.actor_issuer,
    )
  end

  def error_response
    { error: oauth_error, error_description: }
  end

  def error_description
    return errors[:dpop_proof].join(' ') if errors.include?(:dpop_proof)

    errors.map { |error| error.options[:type]&.to_s || error.full_message }.join(' ')
  end

  # RFC 6749 §5.2, with RFC 9449's `invalid_dpop_proof`.
  def oauth_error
    return 'invalid_request' if missing_required_attrs?
    return 'unsupported_grant_type' if errors.include?(:grant_type)
    return 'invalid_client' if errors.include?(:client_id)
    return 'invalid_dpop_proof' if errors.include?(:dpop_proof)
    return 'invalid_scope' if errors.include?(:scope)

    'invalid_grant'
  end

  def missing_required_attrs?
    REQUIRED_ATTRS.any? { |attr| errors.where(attr, :blank).any? }
  end

  def extra_analytics_attributes
    {
      client_id:,
      user_id: (identity&.user&.uuid if stored_token.present?),
      token_exchange_stage: TokenExchange::Constants::STAGE_SUBJECT_TOKEN_REFRESH,
      token_exchange_resource: stored_token&.resource,
      refresh_token_family_id: stored_token&.family_id,
      reuse_detected: !!@reuse_detected,
      oauth_error_code: (oauth_error unless errors.empty?),
    }
  end
end
