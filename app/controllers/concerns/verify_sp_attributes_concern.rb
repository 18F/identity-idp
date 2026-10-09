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
    elsif biometric_consent_needed?(sp_session_identity)
      :biometric_consent_needed
    end
  end

  def update_verified_attributes
    identity = IdentityLinker.new(current_user, current_sp).link_identity(
      ial: linked_identity_ial,
      verified_attributes: sp_session[:requested_attributes],
      last_consented_at: Time.zone.now,
      clear_deleted_at: true,
    )

    # Record the user's token-exchange decision whenever this screen runs. The
    # grant is per application: "allow all" materializes one row per currently
    # connected application rather than a wildcard, so each has its own
    # timestamp and later per-application toggles never fight an "all" state.
    # Applications the user did not choose this time are revoked (not deleted),
    # so a changed decision never leaves stale authorizations behind.
    #
    # Auto-enrollment is a separate per-broker setting: when on, applications
    # the user connects LATER are granted with a timestamp of this consent
    # moment, not of first use. (The exchange endpoint additionally requires the
    # presented token's own scope to include token_exchange.)
    record_token_exchange_decision if token_exchange_consent_requested?

    # Record biometric sharing consent as a distinct, purpose-specific decision;
    # only touched for allow-listed SPs, and set-or-cleared so stale consent
    # never carries over to a new proofing session or a dropped scope.
    if current_sp&.document_images_sharing_allowed?
      identity&.update!(
        biometric_sharing_consent_at: (Time.zone.now if biometric_sharing_consent_granted?),
      )
    end

    # When the user connects a new application, auto-enroll it for every broker
    # the user has opted into auto-enrollment for.
    auto_enroll_token_exchange
  end

  def record_token_exchange_decision
    broker = current_sp.issuer
    now = Time.zone.now

    TokenExchangeGrant.grant!(
      user: current_user, broker_issuer: broker, targets: token_exchange_grant_targets,
      granted_at: now
    )

    setting = TokenExchangeBrokerSetting.for(user: current_user, broker_issuer: broker)
    if token_exchange_auto_enroll?
      setting.enable_auto_enroll!(now: now)
    elsif setting.persisted?
      setting.disable_auto_enroll!(now: now)
    end
  end

  def auto_enroll_token_exchange
    target = current_sp
    return if target.blank? || !target.delegation_application?

    TokenExchangeBrokerSetting.where(user: current_user)
      .where.not(broker_issuer: target.issuer)
      .find_each { |setting| setting.auto_enroll!(target) }
  end

  # True when the SP is an allow-listed broker, requested the token_exchange
  # scope, and the user granted at least one application or auto-enrollment.
  # Consent to token exchange is optional: declining still completes the
  # broker's own sign-in.
  def token_exchange_consent_granted?
    token_exchange_consent_requested? &&
      (token_exchange_grant_targets.any? || token_exchange_auto_enroll?)
  end

  def token_exchange_consent_requested?
    current_sp&.delegation_service_provider? &&
      decorated_sp_session.requested_attributes.map(&:to_s).include?('token_exchange')
  end

  # The user chose "allow all currently linked agencies".
  def token_exchange_all?
    ActiveModel::Type::Boolean.new.cast(token_exchange_form_params[:token_exchange_all]) == true
  end

  # The user chose auto-enrollment. It depends on "allow all" when the user has
  # linked agencies (enforced here, not just in the UI); offered on its own when
  # they have none.
  def token_exchange_auto_enroll?
    checked = ActiveModel::Type::Boolean.new.cast(
      token_exchange_form_params[:token_exchange_auto_enroll],
    ) == true
    return checked if token_exchange_linked_targets.empty?

    checked && token_exchange_all?
  end

  def token_exchange_linked_targets
    @token_exchange_linked_targets ||= DelegationApplications.connected_for(
      user: current_user, service_provider_issuer: current_sp.issuer,
    )
  end

  # Target issuers to grant. "Allow all" covers every application the user has
  # ALREADY linked to their account that has opted in to the broker; otherwise
  # the specific applications chosen. Submitted issuers outside the user's
  # linked, opted-in set are ignored rather than granted.
  def token_exchange_grant_targets
    return @token_exchange_grant_targets if defined?(@token_exchange_grant_targets)

    linked = token_exchange_linked_targets.map(&:issuer)
    @token_exchange_grant_targets =
      if token_exchange_all?
        linked
      else
        Array(token_exchange_form_params[:token_exchange_targets]).map(&:to_s) & linked
      end
  end

  def token_exchange_form_params
    form = params[:idv_form]
    form.is_a?(ActionController::Parameters) ? form : {}
  end

  # True only when the SP is allow-listed, the SP requested document_images, and
  # the user affirmatively checked the biometric-sharing consent box.
  def biometric_sharing_consent_granted?
    biometric_sharing_consent_requested? && biometric_sharing_consent_checked?
  end

  def biometric_sharing_consent_requested?
    current_sp&.document_images_sharing_allowed? &&
      Array(sp_session[:requested_attributes]).map(&:to_s).include?('document_images')
  end

  def biometric_sharing_consent_checked?
    form_params = params[:idv_form]
    return false unless form_params.is_a?(ActionController::Parameters)

    ActiveModel::Type::Boolean.new.cast(form_params[:biometric_sharing_consent])
  end

  # Re-prompt the handoff screen whenever an allow-listed SP requests
  # document_images but the user has no current, fresh biometric consent
  # (never granted, expired, or invalidated by a newer proofing).
  #
  # Only fires when the user has a verified profile: without one there is nothing
  # shareable and consent could never validate (the release gate fails closed on
  # a missing verified_at), so prompting would loop forever for e.g. an IALmax
  # request from an unverified user.
  def biometric_consent_needed?(sp_session_identity)
    return false unless biometric_sharing_consent_requested?

    active_profile = current_user&.active_profile
    return false if active_profile&.verified_at.blank?

    !sp_session_identity.biometric_sharing_consented?(active_profile)
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
