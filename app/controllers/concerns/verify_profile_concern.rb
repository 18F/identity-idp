module VerifyProfileConcern
  private

  def account_or_verify_profile_path
    public_send "#{account_or_verify_profile_route}_path"
  end

  def account_or_verify_profile_url
    public_send "#{account_or_verify_profile_route}_url"
  end

  def account_or_verify_profile_route
    return 'account' if idv_context? || profile_context?
    return 'account' unless current_user.decorate.pending_profile_requires_verification?
    verify_profile_route
  end

  def verify_profile_route
    decorated_user = current_user.decorate
    if decorated_user.needs_profile_phone_verification?
      flash[:notice] = t('account.index.verification.instructions')
      return 'verify_profile_phone'
    end
    return 'verify_account' if decorated_user.needs_profile_usps_verification?
  end

  def profile_needs_verification?
    return false if current_user.blank?
    current_user.decorate.pending_profile_requires_verification?
  end
end
