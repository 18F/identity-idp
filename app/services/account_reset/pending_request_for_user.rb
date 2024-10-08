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

    def cancel_account_reset_request!(cancelled_at:)
      # rubocop:disable Rails/SkipsModelValidations
      result = AccountResetRequest.where(
        user: user,
        granted_at: nil,
        cancelled_at: nil,
      ).where(
        'requested_at > ?',
        account_reset_wait_period_days(user).ago,
      ).order(requested_at: :asc).limit(1).update_all(cancelled_at: cancelled_at)
      # rubocop:enable Rails/SkipsModelValidations

      result == 1
    end
  end
end
