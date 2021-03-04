module AccountReset
  class FindPendingRequestForUser
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
        Identity::Hostdata.settings.account_reset_wait_period_days.to_i.days.ago,
      ).order(requested_at: :asc).first
    end
  end
end
