module Idv
  class UspsMail
    MAX_MAIL_EVENTS = Figaro.env.max_mail_events.to_i
    MAIL_EVENTS_WINDOW_DAYS = Figaro.env.max_mail_events_window_in_days.to_i

    def initialize(current_user)
      @current_user = current_user
    end

    def mail_spammed?
      max_events? && updated_within_last_month?
    end

    private

    attr_reader :current_user

    def user_mail_events
      @_user_mail_events ||= current_user.events.
                             usps_mail_sent.
                             order('updated_at DESC').
                             limit(MAX_MAIL_EVENTS)
    end

    def max_events?
      user_mail_events.count == MAX_MAIL_EVENTS
    end

    def updated_within_last_month?
      user_mail_events.last.updated_at > MAIL_EVENTS_WINDOW_DAYS.days.ago
    end
  end
end
