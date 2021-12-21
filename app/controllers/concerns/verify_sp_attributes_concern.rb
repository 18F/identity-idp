module VerifySpAttributesConcern
  def needs_completions_screen?
    sp_session[:issuer].present? &&
      (sp_session_identity.nil? ||
        !requested_attributes_verified? ||
        consent_has_expired? ||
        consent_was_revoked?)
  end

  def needs_completion_screen_reason
    return nil if sp_session[:issuer].blank?

    if sp_session_identity.nil?
      :new_sp
    elsif !requested_attributes_verified?
      :new_attributes
    elsif consent_has_expired?
      :consent_expired
    elsif consent_was_revoked?
      :consent_revoked
    end
  end

  def update_verified_attributes
    IdentityLinker.new(
      current_user,
      sp_session[:issuer],
    ).link_identity(
      ial: sp_session_ial,
      verified_attributes: sp_session[:requested_attributes],
      last_consented_at: Time.zone.now,
      clear_deleted_at: true,
    )
  end

  def consent_has_expired?
    return false unless sp_session_identity
    return false if sp_session_identity.deleted_at.present?
    last_estimated_consent = sp_session_identity.last_consented_at || sp_session_identity.created_at
    !last_estimated_consent ||
      last_estimated_consent < ServiceProviderIdentity::CONSENT_EXPIRATION.ago ||
      verified_after_consent?(last_estimated_consent)
  end

  def consent_was_revoked?
    return false unless sp_session_identity
    sp_session_identity.deleted_at.present?
  end

  private

  def verified_after_consent?(last_estimated_consent)
    verification_timestamp = current_user.active_profile&.verified_at

    verification_timestamp.present? && last_estimated_consent < verification_timestamp
  end

  def sp_session_identity
    @sp_session_identity =
      current_user&.identities&.find_by(service_provider: sp_session[:issuer])
  end

  def requested_attributes_verified?
    @sp_session_identity && (
      Array(sp_session[:requested_attributes]) - @sp_session_identity.verified_attributes.to_a
    ).empty?
  end
end
