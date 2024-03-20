module AccountReset
  class FindPendingRequestForUser
    include AccountResetConcern
    attr_reader :user

    def initialize(user)
      @user = user
    end

    def call
      AccountResetRequest.where(
        user: user,
        granted_at: nil,
        cancelled_at: nil,
      ).where(
        'requested_at > ?',
        account_reset_wait_period_days(user).ago,
      ).order(requested_at: :asc).first
    end
  end
end
