module Idv
  class GpoMail
    MAX_MAIL_EVENTS = IdentityConfig.store.max_mail_events
    MAIL_EVENTS_WINDOW_DAYS = IdentityConfig.store.max_mail_events_window_in_days
    MINIMUM_WAIT_BEFORE_ANOTHER_USPS_LETTER_IN_HOURS =
      IdentityConfig.store.minimum_wait_before_another_usps_letter_in_hours

    def initialize(current_user)
      @current_user = current_user
    end

    def mail_spammed?
      return true if max_events? && updated_within_last_month?
      too_recent?
    end

    def profile_too_old?
      return false if !current_user.pending_profile

      min_creation_date = IdentityConfig.store.
        gpo_max_profile_age_to_send_letter_in_days.days.ago

      current_user.pending_profile.created_at < min_creation_date
    end

    # Next two methods are analytics helpers used from GpoController and ReviewController

    # Caveat: If the user succeeds on their final phone attempt, the :proof_address
    # RateLimiter is reset to 0. But they probably wouldn't be doing verify by mail
    # if they succeeded on the phone step.
    def phone_step_attempts
      RateLimiter.new(user: @current_user, rate_limit_type: :proof_address).attempts
    end

    def hours_since_first_letter(first_letter_requested_at)
      first_letter_requested_at ?
        (Time.zone.now - first_letter_requested_at).to_i.seconds.in_hours.to_i : 0
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
      (last_updated_at = user_mail_events.last&.updated_at) &&
        last_updated_at > MAIL_EVENTS_WINDOW_DAYS.days.ago
    end

    def too_recent?
      (last_email_time = user_mail_events&.first&.updated_at) &&
        last_email_time > MINIMUM_WAIT_BEFORE_ANOTHER_USPS_LETTER_IN_HOURS.hours.ago
    end
  end
end
