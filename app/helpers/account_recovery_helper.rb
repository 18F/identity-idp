# frozen_string_literal: true

module AccountRecoveryHelper
  # Authenticating with an existing method cancels a request that has not yet
  # been redeemed, so the user is warned before they do so.
  def account_recovery_cancellable_by_authentication?
    return false if current_user.blank? || current_user.is_a?(AnonymousUser)

    AccountRecoveryRequest.active_for_user(current_user)&.awaiting_link_redemption? || false
  end
end
