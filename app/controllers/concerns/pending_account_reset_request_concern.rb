module PendingAccountResetRequestConcern
  extend ActiveSupport::Concern

  def pending_account_reset_request(user)
    AccountResetRequest.where(
      user_id: user.id,
      granted_at: nil,
      cancelled_at: nil,
    ).order(requested_at: :asc).first
  end
end
