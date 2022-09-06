module VerifySpAttributesConcern
  def needs_completion_screen_reason
    return nil if sp_session[:issuer].blank?
    return nil if sp_session[:request_url].blank?

    if @use_cache
      @sp_session_identity = cached_sp_session_identity
      if @sp_session_identity.nil?
        :new_sp
      elsif !cached_requested_attributes_verified?(@sp_session_identity)
        :new_attributes
      elsif cached_consent_has_expired?(@sp_session_identity)
        :consent_expired
      elsif cached_consent_was_revoked?(@sp_session_identity)
        :consent_revoked
      end
    else
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
  end

  def update_verified_attributes
    IdentityLinker.new(
      current_user,
      current_sp,
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

  def cached_consent_has_expired?(sp_session_identity)
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

  def cached_consent_was_revoked?(sp_session_identity)
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

  def cached_sp_session_identity
    current_user&.identities&.find_by(service_provider: sp_session[:issuer])
  end

  def requested_attributes_verified?
    @sp_session_identity && (
      Array(sp_session[:requested_attributes]) - @sp_session_identity.verified_attributes.to_a
    ).empty?
  end

  def cached_requested_attributes_verified?(sp_session_identity)
    sp_session_identity && (
      Array(sp_session[:requested_attributes]) - sp_session_identity.verified_attributes.to_a
    ).empty?
  end
end
