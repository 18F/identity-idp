module VerifyProfileConcern
  private

  def account_or_verify_profile_url
    return reactivate_account_url if user_needs_to_reactivate_account?
    return idv_gpo_verify_url if profile_needs_verification?
    account_url
  end

  def profile_needs_verification?
    return false if current_user.blank?
    current_user.gpo_verification_pending_profile? ||
      user_needs_to_reactivate_account?
  end
end
