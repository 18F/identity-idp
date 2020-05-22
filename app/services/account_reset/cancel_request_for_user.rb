module AccountReset
  class CancelRequestForUser
    attr_reader :user

    def initialize(user)
      @user = user
    end

    def call
      account_reset_request.update!(cancelled_at: Time.zone.now)
    end

    private

    def account_reset_request
      FindPendingRequestForUser.new(user).call
    end
  end
end
