# frozen_string_literal: true

module VerifyProfileConcern
  private

  def url_for_pending_profile_reason
    return idv_verify_by_mail_enter_code_url if current_user.gpo_verification_pending_profile?
    return idv_in_person_ready_to_verify_url if current_user.in_person_pending_profile?
    return idv_please_call_url if current_user.fraud_review_pending?
    idv_not_verified_url if current_user.fraud_rejection?
  end

  def user_has_pending_profile?
    pending_profile_policy.user_has_pending_profile? && !user_failed_ipp_with_fraud_review_pending?
  end

  def pending_profile_policy
    @pending_profile_policy ||= PendingProfilePolicy.new(
      user: current_user,
      resolved_authn_context_result: resolved_authn_context_result,
    )
  end

  # Returns true if the user has not passed IPP at the post office and is
  # flagged for fraud review, or has been rejected for fraud.
  # Ultimately this is to allow users who fail at the post office to create another enrollment
  # bypassing the typical flow of showing the Please Call or Fraud Rejection screens.
  def user_failed_ipp_with_fraud_review_pending?
    IdentityConfig.store.in_person_proofing_enforce_tmx &&
      current_user.ipp_enrollment_status_not_passed_or_in_fraud_review? &&
      current_user.fraud_review_pending?
  end
end
