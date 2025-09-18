# frozen_string_literal: true

module OneAccountConcern
  extend ActiveSupport::Concern

  def log_one_account_self_service_if_applicable(source:)
    return unless current_user&.active_profile&.facial_match?
    sets = DuplicateProfileSet
      .duplicate_profile_set_for_profile(profile_id: current_user.active_profile.id)
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
    login_success_after_dupe_deletion?(profile_set: dupe_profile_set)
    dupe_profile_set.present? && dupe_profile_set.closed_at.nil?
  end

  def user_eligible_for_one_account?
    sp_eligible_for_one_account? &&
      current_user&.active_profile && user_in_one_account_verification_bucket?
  end

  def sp_eligible_for_one_account?
    IdentityConfig.store.eligible_one_account_providers.include?(sp_from_sp_session&.issuer)
  end

  def profile_creation_duplicate_profile_detected?
    return false unless IdentityConfig.store.one_account_profile_creation_check_enabled
    user_has_duplicate_account_profiles?
  end

  def user_in_one_account_verification_bucket?
    return true if user_has_duplicate_account_profiles?
    ab_test_bucket(:ONE_ACCOUNT_USER_VERIFICATION_ENABLED) == :one_account_user_verification_enabled
  end

  def user_has_duplicate_account_profiles?
    DuplicateProfileSet.involving_profile(
      profile_id: current_user.active_profile.id,
      service_provider: sp_from_sp_session&.issuer,
    ).present?
  end

  def login_success_after_dupe_deletion?(profile_set: dupe_profile_set)
    if profile_set.present? && profile_set.closed_at.present?
      analytics.one_account_login_success_after_dupe_deletion
    end
  end
end
