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
    elsif delegation_consent_needed?
      :delegation_requested
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

    # Record the person's approval of the applications the service provider requested. The screen
    # shows them locked, so continuing approves every requested application; the only choice made
    # here is whether to remember the approvals.
    record_delegation_consent if delegation_consent_requested?

    # Record biometric sharing consent as a distinct, purpose-specific decision;
    # only touched for allow-listed SPs, and set-or-cleared so stale consent
    # never carries over to a new proofing session or a dropped scope.
    if current_sp&.document_images_sharing_allowed?
      identity&.update!(
        biometric_sharing_consent_at: (Time.zone.now if biometric_sharing_consent_granted?),
      )
    end
  end

  def record_delegation_consent
    @delegation_consent_result = TokenExchangeConsent.new(
      user: current_user,
      service_provider: current_sp,
      applications: requested_delegation_applications,
      remember: delegation_remember?,
      rails_session_id: session.id.to_s,
      proofed_in_session: identity_verified_in_this_session?,
    ).call
    # The person has answered for this authorization; the screen is not shown again before the
    # handoff completes, whatever the remember choice was.
    user_session[:delegation_consent_authorization] = delegation_authorization_key
  end

  # The approvals written by the submit that just ran, for analytics.
  def delegation_consent_result
    @delegation_consent_result
  end

  # The screen is needed when the service provider requested applications and any of them lacks
  # an approval that is remembered and current. It is not shown twice for one authorization: the
  # person's answer is keyed to the authorize URL (fresh state and nonce per authorization), which
  # the service provider's request id does not distinguish.
  def delegation_consent_needed?
    return false unless delegation_consent_requested?
    return false if delegation_consent_given_for_current_authorization?

    TokenExchangeGrant.partition_current(
      user: current_user, service_provider_issuer: current_sp.issuer,
      applications: requested_delegation_applications
    )[:needing_approval].any?
  end

  def delegation_consent_given_for_current_authorization?
    key = delegation_authorization_key
    key.present? && user_session[:delegation_consent_authorization] == key
  end

  def delegation_authorization_key
    url = sp_session[:request_url]
    url.present? ? Digest::SHA256.hexdigest(url) : nil
  end

  def delegation_consent_requested?
    current_sp&.delegation_service_provider? && requested_delegation_applications.any?
  end

  # The applications named in the request, as registry records, in request order.
  # @return [Array<ServiceProvider>]
  def requested_delegation_applications
    @requested_delegation_applications ||= DelegationApplications.requested(
      current_sp&.issuer, decorated_sp_session.requested_delegation_scopes
    )
  end

  # The one choice the screen offers for delegation: remember these approvals for the maximum
  # period, or keep them for this authorization only.
  def delegation_remember?
    form = params[:idv_form]
    return false unless form.is_a?(ActionController::Parameters)

    ActiveModel::Type::Boolean.new.cast(form[:delegation_remember]) == true
  end

  # Whether the person's identity was verified during this browser session, recorded on the
  # approval so reporting can attribute the verification to the service provider's sign-in.
  def identity_verified_in_this_session?
    profile = current_user.active_profile
    return false unless profile&.verified_at

    user_session.dig(:idv, :profile_id).to_s == profile.id.to_s ||
      profile.verified_at > (session[:created_at] || 1.day.ago)
  rescue StandardError
    false
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
