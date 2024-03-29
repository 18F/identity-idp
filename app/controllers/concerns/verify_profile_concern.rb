module VerifyProfileConcern
  private

  def url_for_pending_profile_reason
    return idv_verify_by_mail_enter_code_url if current_user.gpo_verification_pending_profile?
    return idv_in_person_ready_to_verify_url if current_user.in_person_pending_profile?
    return idv_please_call_url if current_user.fraud_review_pending?
    idv_not_verified_url if current_user.fraud_rejection?
  end

  def user_has_pending_profile?
    pending_profile_policy.user_has_pending_profile?
  end

  def pending_profile_policy
    @pending_profile_policy ||= PendingProfilePolicy.new(
      user: current_user,
      resolved_authn_context_result: resolved_authn_context_result,
      biometric_comparison_requested: nil,
    )
  end
end
