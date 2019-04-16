module RecurringJob
  class SendAccountResetNotificationsController < BaseController
    def create
      count = AccountReset::GrantRequestsAndSendEmails.new.call
      analytics.track_event(Analytics::ACCOUNT_RESET, event: :notifications, count: count)
      render plain: 'ok'
    end

    private

    def config_auth_token
      Figaro.env.account_reset_auth_token
    end
  end
end
