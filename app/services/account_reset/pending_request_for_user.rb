# frozen_string_literal: true

module AccountReset
  class PendingRequestForUser
    include AccountResetConcern
    attr_reader :user

    def initialize(user)
      @user = user
    end

    def get_account_reset_request
      AccountResetRequest.where(
        user: user,
        granted_at: nil,
        cancelled_at: nil,
      ).where(
        'requested_at > ?',
        account_reset_wait_period_days(user).ago,
      ).order(requested_at: :asc).first
    end

    def cancel_account_reset_request!(account_reset_request_id:, cancelled_at:)
      # rubocop:disable Rails/SkipsModelValidations
      result = AccountResetRequest.where(
        id: account_reset_request_id,
        user: user,
        granted_at: nil,
        cancelled_at: nil,
      ).where(
        'requested_at > ?',
        account_reset_wait_period_days(user).ago,
      ).update_all(cancelled_at: cancelled_at, updated_at: Time.zone.now)
      # rubocop:enable Rails/SkipsModelValidations

      if result == 1
        NotifyUserOfRequestCancellation.new(user).call
        true
      else
        false
      end
    end
  end
end
