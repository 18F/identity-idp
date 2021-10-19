module VerifyProfileConcern
  private

  def account_or_verify_profile_url
    return reactivate_account_url if user_needs_to_reactivate_account?
    return account_url unless profile_needs_verification?
    return idv_gpo_url if gpo_mail_bounced?
    verify_account_url
  end

  def profile_needs_verification?
    return false if current_user.blank?
    current_user.decorate.pending_profile_requires_verification? ||
      user_needs_to_reactivate_account?
  end

  def gpo_mail_bounced?
    current_user.decorate.gpo_mail_bounced?
  end
end
