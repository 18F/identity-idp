# frozen_string_literal: true

class PendingProfilePolicy
  def initialize(user:, resolved_authn_context_result:)
    @user = user
    @resolved_authn_context_result = resolved_authn_context_result
  end

  def user_has_pending_profile?
    return false if user.blank?

    if facial_match_requested?
      pending_facial_match_profile?
    else
      pending_legacy_profile? || fraud_review_pending?
    end
  end

  private

  attr_reader :user, :resolved_authn_context_result

  def pending_facial_match_profile?
    Profile::FACIAL_MATCH_IDV_LEVELS.include?(user.pending_profile&.idv_level)
  end

  def facial_match_requested?
    resolved_authn_context_result.facial_match?
  end

  def pending_legacy_profile?
    user.pending_profile&.present? &&
      user.pending_profile.idv_level != 'unsupervised_with_selfie'
  end

  def fraud_review_pending?
    user.fraud_review_pending?
  end
end
