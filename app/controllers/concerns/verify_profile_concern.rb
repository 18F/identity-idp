module VerifyProfileConcern
  private

  def account_or_verify_profile_url
    return reactivate_account_url if user_needs_to_reactivate_account?
    return account_url unless profile_needs_verification?
    idv_gpo_verify_url
  end

  def profile_needs_verification?
    return false if current_user.blank?
    return false if sp_session[:ial2_strict] &&
                    !IdentityConfig.store.gpo_allowed_for_strict_ial2
    current_user.decorate.pending_profile_requires_verification? ||
      user_needs_to_reactivate_account?
  end
end
