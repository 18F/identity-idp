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

    # Record the user's delegated-access decision whenever this screen runs for a service provider
    # that asked for it: one approval row per chosen application, and a revocation for every
    # connected application the user did not choose this time, so a changed decision never leaves
    # a stale approval behind.
    record_delegation_decision if delegation_consent_requested?

    # Record biometric sharing consent as a distinct, purpose-specific decision;
    # only touched for allow-listed SPs, and set-or-cleared so stale consent
    # never carries over to a new proofing session or a dropped scope.
    if current_sp&.document_images_sharing_allowed?
      identity&.update!(
        biometric_sharing_consent_at: (Time.zone.now if biometric_sharing_consent_granted?),
      )
    end
  end

  def record_delegation_decision
    now = Time.zone.now
    chosen = approved_delegation_applications

    chosen.each do |application|
      # Approvals from this screen are remembered for the maximum period.
      TokenExchangeGrant.approve!(
        user: current_user, service_provider: current_sp, application:,
        source: 'consent_screen', remember: true, now:
      )
    end
    (connected_delegation_applications - chosen).each do |application|
      TokenExchangeGrant.revoke_for!(
        user: current_user, service_provider_issuer: current_sp.issuer, application:,
        reason: 'user_revoked', now:
      )
    end
  end

  # True when the service provider is approved for delegation, asked for it in this sign-in, and
  # the user approved at least one application. Consent to delegation is optional: declining still
  # completes the service provider's own sign-in.
  def delegation_consent_granted?
    delegation_consent_requested? && approved_delegation_applications.any?
  end

  def delegation_consent_requested?
    current_sp&.delegation_service_provider? &&
      decorated_sp_session.requested_attributes.map(&:to_s).include?('token_exchange')
  end

  # The user chose "allow all connected applications".
  def delegation_all?
    ActiveModel::Type::Boolean.new.cast(delegation_form_params[:delegation_all]) == true
  end

  def connected_delegation_applications
    @connected_delegation_applications ||= DelegationApplications.connected_for(
      user: current_user, service_provider_issuer: current_sp.issuer,
    )
  end

  # Applications to approve: every connected application that accepts the service provider when
  # the user chose "allow all", otherwise the specific applications chosen. Submitted issuers
  # outside that set are ignored rather than approved.
  # @return [Array<ServiceProvider>]
  def approved_delegation_applications
    return @approved_delegation_applications if defined?(@approved_delegation_applications)

    connected = connected_delegation_applications
    @approved_delegation_applications =
      if delegation_all?
        connected
      else
        chosen_issuers = Array(delegation_form_params[:delegation_applications]).map(&:to_s)
        connected.select { |application| chosen_issuers.include?(application.issuer) }
      end
  end

  def delegation_form_params
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
