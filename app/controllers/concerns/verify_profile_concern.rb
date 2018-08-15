module VerifyProfileConcern
  private

  def account_or_verify_profile_path
    public_send "#{account_or_verify_profile_route}_path"
  end

  def account_or_verify_profile_url
    public_send "#{account_or_verify_profile_route}_url"
  end

  def account_or_verify_profile_route
    return 'account' unless profile_needs_verification?
    'verify_account'
  end

  def profile_needs_verification?
    return false if current_user.blank?
    current_user.decorate.pending_profile_requires_verification?
  end
end
