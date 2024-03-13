class PendingProfilePolicy
  def initialize(user:, resolved_authn_context_result:, biometric_comparison_requested:)
    @user = user
    @resolved_authn_context_result = resolved_authn_context_result
    @biometric_comparison_requested = biometric_comparison_requested
  end

  def user_has_usable_pending_profile?
    if biometric_comparison_requested?
      pending_biometric_profile?
    else
      pending_legacy_profile? || fraud_review_pending?
    end
  end

  private

  attr_reader :user, :resolved_authn_context_result, :biometric_comparison_requested

  def active_biometric_profile?
    user.active_profile&.idv_level == 'unsupervised_with_selfie'
  end

  def pending_biometric_profile?
    user.pending_profile&.idv_level == 'unsupervised_with_selfie'
  end

  def biometric_comparison_requested?
    return false if !FeatureManagement.idv_allow_selfie_check?
    resolved_authn_context_result.biometric_comparison? || biometric_comparison_requested
  end

  def pending_legacy_profile?
    user.pending_profile.present? && user.pending_profile&.idv_level != 'unsupervised_with_selfie'
  end

  def fraud_review_pending?
    user.fraud_review_pending?
  end
end
