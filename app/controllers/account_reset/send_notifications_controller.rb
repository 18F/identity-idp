# This controller is not user-facing. It is only accessed by an AWS Lambda that
# is triggered by CloudWatch to run on a recurring basis. The Lambda is defined
# in lib/lambdas/account_reset_lambda.rb
module AccountReset
  class SendNotificationsController < ApplicationController
    skip_before_action :verify_authenticity_token
    before_action :authorize

    def update
      count = AccountReset::GrantRequestsAndSendEmails.new.call
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
