module SecondMfaReminderConcern
  def user_needs_second_mfa_reminder?
    return false unless IdentityConfig.store.second_mfa_reminder_enabled
    return false if user_has_dismissed_second_mfa_reminder?
    return false if second_mfa_enrollment_may_downgrade_for_service_provider_mfa_requirement?
    return false if user_has_multiple_mfa_methods?
    exceeded_sign_in_count_for_second_mfa_reminder? || exceeded_account_age_for_second_mfa_reminder?
  end

  private

  def second_mfa_enrollment_may_downgrade_for_service_provider_mfa_requirement?
    service_provider_mfa_policy.phishing_resistant_required? ||
      service_provider_mfa_policy.piv_cac_required?
  end

  def user_has_dismissed_second_mfa_reminder?
    current_user.second_mfa_reminder_dismissed_at.present?
  end

  def user_has_multiple_mfa_methods?
    MfaContext.new(current_user).enabled_mfa_methods_count > 1
  end

  def exceeded_sign_in_count_for_second_mfa_reminder?
    current_user.sign_in_count(since: second_mfa_reminder_account_age_cutoff) >=
      IdentityConfig.store.second_mfa_reminder_sign_in_count
  end

  def exceeded_account_age_for_second_mfa_reminder?
    current_user.created_at.before?(second_mfa_reminder_account_age_cutoff)
  end

  def second_mfa_reminder_account_age_cutoff
    IdentityConfig.store.second_mfa_reminder_account_age_in_days.days.ago
  end
end
