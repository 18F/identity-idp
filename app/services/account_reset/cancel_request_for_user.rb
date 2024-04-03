# frozen_string_literal: true

module AccountReset
  class CancelRequestForUser
    attr_reader :user

    def initialize(user)
      @user = user
    end

    def call(now: Time.zone.now)
      account_reset_request.update!(cancelled_at: now)
      NotifyUserOfRequestCancellation.new(user).call
    end

    private

    def account_reset_request
      FindPendingRequestForUser.new(user).call
    end
  end
end
