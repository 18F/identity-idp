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

    # Record token-exchange consent as a distinct, purpose-specific decision;
    # only touched for allow-listed brokers, and set-or-cleared whenever this
    # screen runs so a dropped scope or new proofing session does not carry
    # stale consent forward. (The exchange endpoint additionally requires the
    # presented token's own scope to include token_exchange, so consent can
    # never outlive the grant it was given for.)
    if current_sp&.token_exchange_broker_allowed?
      identity&.update!(
        token_exchange_consent_at: (Time.zone.now if token_exchange_consent_granted?),
      )
    end

    # Record biometric sharing consent as a distinct, purpose-specific decision;
    # only touched for allow-listed SPs, and set-or-cleared so stale consent
    # never carries over to a new proofing session or a dropped scope.
    if current_sp&.document_images_sharing_allowed?
      identity&.update!(
        biometric_sharing_consent_at: (Time.zone.now if biometric_sharing_consent_granted?),
      )
    end
  end

  # True only when the SP is an allow-listed broker, requested the
  # token_exchange scope, and the user affirmatively checked the consent box.
  def token_exchange_consent_granted?
    token_exchange_consent_requested? && token_exchange_consent_checked?
  end

  def token_exchange_consent_requested?
    current_sp&.token_exchange_broker_allowed? &&
      decorated_sp_session.requested_attributes.map(&:to_s).include?('token_exchange')
  end

  def token_exchange_consent_checked?
    form = params[:idv_form]
    return false unless form.respond_to?(:[]) && !form.is_a?(String)
    ActiveModel::Type::Boolean.new.cast(form[:token_exchange_consent])
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
