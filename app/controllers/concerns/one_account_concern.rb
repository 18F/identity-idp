# frozen_string_literal: true

module OneAccountConcern
  extend ActiveSupport::Concern

  def process_one_account_self_service_if_applicable(source:)
    return unless current_user&.active_profile&.facial_match?
    user_profile_id = current_user.active_profile.id
    sets = DuplicateProfileSet
      .duplicate_profile_sets_for_profile(profile_id: user_profile_id)
    return if sets.blank?

    sets.each do |set|
      analytics.one_account_self_service(
        source: source,
        service_provider: set.service_provider,
        associated_profiles_count: set.profile_ids.count - 1,
        dupe_profile_set_id: set.id,
      )
    end
  end

  def handle_duplicate_profile_user(source: :sign_in)
    return unless user_duplicate_profiles_detected?
    redirect_to duplicate_profiles_detected_url(source: source)
  end

  def user_duplicate_profiles_detected?
    return false unless user_eligible_for_one_account?
    dupe_profile_set = DuplicateProfileChecker.new(
      user: current_user,
      user_session: user_session,
      sp: sp_from_sp_session,
      analytics: analytics,
    ).dupe_profile_set_for_user
    dupe_profile_set.present? && dupe_profile_set.closed_at.nil?
  end

  def user_eligible_for_one_account?
    return false unless facial_match_request?

    if global_detection_enabled?
      current_user&.identity_verified_with_facial_match?
    else
      sp_eligible_for_one_account? && current_user&.identity_verified_with_facial_match?
    end
  end

  def facial_match_request?
    resolved_authn_context_result&.facial_match? || false
  end

  def sp_eligible_for_one_account?
    IdentityConfig.store.eligible_one_account_providers.include?(sp_from_sp_session&.issuer)
  end

  def profile_creation_duplicate_profile_detected?
    user_has_duplicate_account_profiles?
  end

  def global_detection_enabled?
    IdentityConfig.store.enable_one_account_global_detection
  end

  def user_has_duplicate_account_profiles?
    if global_detection_enabled?
      DuplicateProfileSet.involving_profile_global(
        profile_id: current_user.active_profile.id,
      ).present?
    else
      DuplicateProfileSet.involving_profile(
        profile_id: current_user.active_profile.id,
        service_provider: sp_from_sp_session&.issuer,
      ).present?
    end
  end
end
