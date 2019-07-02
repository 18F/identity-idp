module RecurringJob
  class SendAccountResetNotificationsController < BaseController
    def create
      render(
        plain: 'This endpoint has been removed in favor of idp-jobs.',
        status: :gone,
      )
    end

    private

    def config_auth_token
      Figaro.env.account_reset_auth_token
    end
  end
end
