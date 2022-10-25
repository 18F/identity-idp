module VerifyProfileConcern
  private

  def account_or_verify_profile_url
    return reactivate_account_url if user_needs_to_reactivate_account?
    return idv_gpo_verify_url if profile_needs_verification?
    return backup_code_reminder_url if user_needs_backup_code_reminder?
    account_url
  end

  def user_needs_backup_code_reminder?
    user_backup_codes_configured? && user_last_signed_in_more_than_5_months_ago?
  end

  def user_backup_codes_configured?
    MfaContext.new(current_user).backup_code_configurations.present?
  end

  def user_last_signed_in_more_than_5_months_ago?
    user = UserDecorator.new(current_user)
    second_last_signed_in_at = user.second_last_signed_in_at
    second_last_signed_in_at && second_last_signed_in_at < 5.months.ago
  end

  def profile_needs_verification?
    return false if current_user.blank?
    current_user.decorate.pending_profile_requires_verification? ||
      user_needs_to_reactivate_account?
  end
end
