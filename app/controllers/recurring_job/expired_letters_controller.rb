module RecurringJob
  class ExpiredLettersController < BaseController
    def create
      count = SendExpiredLetterNotifications.new.call
      analytics.track_event(Analytics::EXPIRED_LETTERS, event: :notifications, count: count)
      render plain: 'ok'
    end

    private

    def config_auth_token
      Figaro.env.expired_letters_auth_token
    end
  end
end
