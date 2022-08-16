module VerifyProfileConcern
  private

  def account_or_verify_profile_url
    return reactivate_account_url if user_needs_to_reactivate_account?
    if profile_needs_verification?
      return idv_gpo_url if gpo_mail_bounced?
      return idv_gpo_verify_url
    end
    return backup_code_reminder_url if user_needs_backup_code_reminder?
    account_url
  end

  def user_needs_backup_code_reminder?
    return false unless IdentityConfig.store.kantara_2fa_phone_restricted
    user_backup_codes_configured? && user_last_signed_in_more_than_5_months_ago?
  end

  def user_backup_codes_configured?
    mfa_user = MfaContext.new(current_user)
    mfa_user.backup_code_configurations.present?
  end

  def user_last_signed_in_more_than_5_months_ago?
    user = UserDecorator.new(current_user)
    second_last_signed_in_at = user.second_last_signed_in_at
    second_last_signed_in_at && second_last_signed_in_at < 5.months.ago
  end

  def profile_needs_verification?
    return false if current_user.blank?
    return false if sp_session[:ial2_strict] &&
                    !IdentityConfig.store.gpo_allowed_for_strict_ial2
    current_user.decorate.pending_profile_requires_verification? ||
      user_needs_to_reactivate_account?
  end

  def gpo_mail_bounced?
    current_user.decorate.gpo_mail_bounced?
  end
end
