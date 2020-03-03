module VerifySPAttributesConcern
  def needs_completions_screen?
    sp_session[:issuer].present? &&
      (sp_session_identity.nil? ||
        !requested_attributes_verified? ||
        consent_has_expired?)
  end

  def needs_sp_attribute_verification?
    if needs_completions_screen?
      set_verify_shared_attributes_session
      true
    else
      clear_verify_attributes_sessions
      false
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
    )
  end

  def set_verify_shared_attributes_session
    user_session[:verify_shared_attributes] = true
  end

  def new_service_provider_attributes
    user_session[:verify_shared_attributes] if
      user_session.class == ActiveSupport::HashWithIndifferentAccess
  end

  def clear_verify_attributes_sessions
    user_session[:verify_shared_attributes] = false
  end

  def consent_has_expired?
    return true unless sp_session_identity
    last_estimated_consent = sp_session_identity.last_consented_at || sp_session_identity.created_at
    !last_estimated_consent || last_estimated_consent < Identity::CONSENT_EXPIRATION.ago
  end

  private

  def sp_session_identity
    @sp_session_identity =
      current_user&.identities&.find_by(service_provider: sp_session[:issuer])
  end

  def requested_attributes_verified?
    @sp_session_identity && (
      sp_session[:requested_attributes] - @sp_session_identity.verified_attributes.to_a
    ).empty?
  end

  def sp_session_ial
    sp_session[:ial2] ? 2 : 1
  end
end
