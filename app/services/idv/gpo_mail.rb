module Idv
  class GpoMail
    MAX_MAIL_EVENTS = IdentityConfig.store.max_mail_events
    MAIL_EVENTS_WINDOW_DAYS = IdentityConfig.store.max_mail_events_window_in_days

    def initialize(current_user)
      @current_user = current_user
    end

    def mail_spammed?
      return false if user_mail_events.empty?
      max_events? && updated_within_last_month?
    end

    def profile_too_old?
      return false if !current_user.pending_profile

      min_creation_date = IdentityConfig.store.
        gpo_max_profile_age_to_send_letter_in_days.days.ago

      current_user.pending_profile.created_at < min_creation_date
    end

    private

    attr_reader :current_user

    def user_mail_events
      @user_mail_events ||= current_user.events.
        gpo_mail_sent.
        order('updated_at DESC').
        limit(MAX_MAIL_EVENTS)
    end

    def max_events?
      user_mail_events.size == MAX_MAIL_EVENTS
    end

    def updated_within_last_month?
      user_mail_events.last.updated_at > MAIL_EVENTS_WINDOW_DAYS.days.ago
    end
  end
end
