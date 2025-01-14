# frozen_string_literal: true

module BackupCodeReminderConcern
  def user_needs_backup_code_reminder?
    return false if user_session[:dismissed_backup_code_reminder]
    user_backup_codes_configured? && user_last_signed_in_more_than_5_months_ago?
  end

  private

  def user_backup_codes_configured?
    MfaContext.new(current_user).backup_code_configurations.present?
  end

  def user_last_signed_in_more_than_5_months_ago?
    current_user.created_at.before?(5.months.ago) &&
      current_user.second_last_signed_in_at(since: 5.months.ago).blank?
  end
end
