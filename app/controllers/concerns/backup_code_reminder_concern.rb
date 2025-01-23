# frozen_string_literal: true

module BackupCodeReminderConcern
  def user_needs_backup_code_reminder?
    user_session[:dismissed_backup_code_reminder].blank? &&
      auth_events_valid_for_backup_code_reminder? &&
      user_backup_codes_configured? &&
      user_last_signed_in_more_than_5_months_ago?
  end

  private

  def auth_events_valid_for_backup_code_reminder?
    # Exclude backup codes and remembered device for backup code reminders.
    auth_methods_session.auth_events.none? do |auth_event|
      # If the user authenticated using remembered device, they have signed in more recently than
      # 5 months ago. Remembered device authentications do not produce `after_sign_in_2fa` events,
      # which is what's used to consider whether user signed in more than 5 months ago.
      auth_event[:auth_method] == TwoFactorAuthenticatable::AuthMethod::REMEMBER_DEVICE ||
        # If the user authenticated using backup code in the same session, it can be inferred that
        # they still have possession of their backup codes
        auth_event[:auth_method] == TwoFactorAuthenticatable::AuthMethod::BACKUP_CODE
    end
  end

  def user_backup_codes_configured?
    MfaContext.new(current_user).backup_code_configurations.present?
  end

  def user_last_signed_in_more_than_5_months_ago?
    current_user.created_at.before?(5.months.ago) &&
      current_user.second_last_signed_in_at(since: 5.months.ago).blank?
  end
end
