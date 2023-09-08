module VerifyProfileConcern
  private

  def url_for_pending_profile_reason
    return idv_verify_by_mail_enter_code_url if current_user.gpo_verification_pending_profile?
    return idv_in_person_ready_to_verify_url if current_user.in_person_pending_profile?
    return idv_please_call_url if current_user.fraud_review_pending?
    idv_not_verified_url if current_user.fraud_rejection?
  end

  def user_has_pending_profile?
    return false if current_user.blank?
    current_user.pending_profile?
  end
end
