module SecondMfaReminderConcern
  def user_needs_second_mfa_reminder?
    return false if user_has_dismissed_second_mfa_reminder? || user_has_multiple_mfa_methods?
    exceeded_sign_in_count_for_second_mfa_reminder? || exceeded_account_age_for_second_mfa_reminder?
  end

  private

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
