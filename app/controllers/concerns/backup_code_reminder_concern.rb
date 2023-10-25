# frozen_string_literal: true

module BackupCodeReminderConcern
  def user_needs_backup_code_reminder?
    user_backup_codes_configured? && user_last_signed_in_more_than_5_months_ago?
  end

  def user_backup_codes_configured?
    MfaContext.new(current_user).backup_code_configurations.present?
  end

  def user_last_signed_in_more_than_5_months_ago?
    second_last_signed_in_at = current_user.second_last_signed_in_at
    second_last_signed_in_at && second_last_signed_in_at < 5.months.ago
  end
end
