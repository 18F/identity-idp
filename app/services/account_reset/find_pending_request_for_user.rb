module AccountReset
  class FindPendingRequestForUser
    attr_reader :user

    def initialize(user)
      @user = user
    end

    def call
      AccountResetRequest.where(
        user:,
        granted_at: nil,
        cancelled_at: nil,
      ).where(
        'requested_at > ?',
        IdentityConfig.store.account_reset_wait_period_days.days.ago,
      ).order(requested_at: :asc).first
    end
  end
end
