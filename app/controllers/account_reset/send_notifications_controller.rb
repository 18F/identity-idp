module AccountReset
  class SendNotificationsController < ApplicationController
    before_action :authorize

    def update
      count = AccountResetService.grant_tokens_and_send_notifications
      analytics.track_event(Analytics::ACCOUNT_RESET, event: :notifications, count: count)
      render plain: 'ok'
    end

    private

    def authorize
      return if auth_token == Figaro.env.account_reset_auth_token
      head :unauthorized
    end

    def auth_token
      request.headers['X-API-AUTH-TOKEN']
    end
  end
end
