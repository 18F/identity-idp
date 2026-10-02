# frozen_string_literal: true

module VerifySpAttributesConcern
  def needs_completion_screen_reason
    return nil if sp_session[:issuer].blank?
    return nil if sp_session[:request_url].blank?

    sp_session_identity = find_sp_session_identity
    if sp_session_identity.nil?
      :new_sp
    elsif !requested_attributes_verified?(sp_session_identity)
      :new_attributes
    elsif reverified_after_consent?(sp_session_identity)
      :reverified_after_consent
    elsif consent_has_expired?(sp_session_identity)
      :consent_expired
    elsif consent_was_revoked?(sp_session_identity)
      :consent_revoked
    end
  end

  def update_verified_attributes
    IdentityLinker.new(
      current_user,
      current_sp,
    ).link_identity(
      ial: linked_identity_ial,
      verified_attributes: sp_session[:requested_attributes],
      last_consented_at: Time.zone.now,
      clear_deleted_at: true,
    )

    # Record the user's token-exchange grant as a distinct, purpose-specific
    # decision, replacing any prior grants for this broker whenever this screen
    # runs so a changed choice, dropped scope, or new proofing session never
    # carries stale per-application grants forward. (The exchange endpoint
    # additionally requires the presented token's own scope to include
    # token_exchange, so a grant can never outlive the authorization it was
    # given with.)
    if current_sp&.token_exchange_broker_allowed?
      if token_exchange_consent_granted?
        TokenExchangeGrant.record!(
          user: current_user,
          broker_issuer: current_sp.issuer,
          choice: token_exchange_grant_choice,
          targets: token_exchange_grant_targets,
        )
      else
        TokenExchangeGrant.revoke_all!(user: current_user, broker_issuer: current_sp.issuer)
      end
    end
  end

  TOKEN_EXCHANGE_GRANT_CHOICES = %w[all all_and_future specific].freeze

  # True only when the SP is an allow-listed broker, requested the
  # token_exchange scope, and the user made a valid grant choice (for a
  # per-application grant, at least one application must be chosen).
  def token_exchange_consent_granted?
    token_exchange_consent_requested? && token_exchange_consent_checked?
  end

  def token_exchange_consent_requested?
    current_sp&.token_exchange_broker_allowed? &&
      decorated_sp_session.requested_attributes.map(&:to_s).include?('token_exchange')
  end

  # A grant is only valid when it will authorize something: a per-application
  # grant needs at least one chosen application, and an all-current-services
  # grant needs at least one reachable application (otherwise -- e.g. the broker
  # manifest was unavailable -- the user would be left with a 12-month grant that
  # covers nothing). All-and-future may be granted with no current targets since
  # it covers whatever the broker adds.
  def token_exchange_consent_checked?
    choice = token_exchange_grant_choice
    return false unless TOKEN_EXCHANGE_GRANT_CHOICES.include?(choice)
    return true if choice == 'all_and_future'
    token_exchange_grant_targets.any?
  end

  def token_exchange_grant_choice
    token_exchange_form_params[:token_exchange_grant].to_s
  end

  # Issuers the user chose, restricted to the applications the broker may
  # actually reach for this SP -- a submitted issuer outside that set is ignored
  # rather than granted. For an all-targets choice the full reachable set is
  # snapshotted so the grant records exactly what the user saw.
  def token_exchange_grant_targets
    return @token_exchange_grant_targets if defined?(@token_exchange_grant_targets)

    reachable = TokenExchangeReachableTargets.for_broker(current_sp.issuer).map(&:issuer)
    @token_exchange_grant_targets =
      if token_exchange_grant_choice == 'specific'
        Array(token_exchange_form_params[:token_exchange_targets]).map(&:to_s) & reachable
      else
        reachable
      end
  end

  def token_exchange_form_params
    form = params[:idv_form]
    form.is_a?(ActionController::Parameters) ? form : {}
  end

  def consent_has_expired?(sp_session_identity)
    return false unless sp_session_identity
    return false if sp_session_identity.deleted_at.present?
    last_estimated_consent = last_estimated_consent_for(sp_session_identity)
    !last_estimated_consent ||
      last_estimated_consent < ServiceProviderIdentity::CONSENT_EXPIRATION.ago
  end

  def consent_was_revoked?(sp_session_identity)
    return false unless sp_session_identity
    sp_session_identity.deleted_at.present?
  end

  def reverified_after_consent?(sp_session_identity)
    return false unless sp_session_identity
    return false if sp_session_identity.deleted_at.present?
    last_estimated_consent = last_estimated_consent_for(sp_session_identity)
    return false if last_estimated_consent.nil?
    verified_after_consent?(last_estimated_consent)
  end

  private

  def last_estimated_consent_for(sp_session_identity)
    sp_session_identity.last_consented_at || sp_session_identity.created_at
  end

  def verified_after_consent?(last_estimated_consent)
    verification_timestamp = current_user.active_profile&.verified_at

    verification_timestamp.present? && last_estimated_consent < verification_timestamp
  end

  def linked_identity_ial
    if resolved_authn_context_result.ialmax?
      0
    elsif resolved_authn_context_result.identity_proofing?
      2
    else
      1
    end
  end

  def find_sp_session_identity
    current_user&.identities&.find_by(service_provider: sp_session[:issuer])
  end

  def requested_attributes_verified?(sp_session_identity)
    sp_session_identity && (
      Array(sp_session[:requested_attributes]) - sp_session_identity.verified_attributes.to_a
    ).empty?
  end
end
