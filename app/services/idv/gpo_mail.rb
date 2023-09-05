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
      rate_limiting_enabled? &&
        (too_many_mails_within_window? || last_mail_too_recent?)
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

    def rate_limiting_enabled?
      (MAX_MAIL_EVENTS != 0 && MAIL_EVENTS_WINDOW_DAYS != 0) ||
        MINIMUM_WAIT_BEFORE_ANOTHER_USPS_LETTER_IN_HOURS != 0
    end

    def too_many_mails_within_window?
      number_of_emails_within(MAIL_EVENTS_WINDOW_DAYS.days) >= MAX_MAIL_EVENTS
    end

    def last_mail_too_recent?
      number_of_emails_within(MINIMUM_WAIT_BEFORE_ANOTHER_USPS_LETTER_IN_HOURS.hours) > 0
    end

    def number_of_emails_within(time_window)
      profile_hash = { user: current_user }

      pending_profile_id = current_user&.pending_profile&.id
      if pending_profile_id
        profile_hash[:id] = pending_profile_id
      end

      GpoConfirmationCode.joins(:profile).
        where(
          updated_at: (time_window.ago..),
          profile: profile_hash,
        ).count
    end
  end
end
