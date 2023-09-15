module Idv
  class GpoMail
    def initialize(current_user)
      @current_user = current_user
    end

    def mail_spammed?
      too_many_letter_requests_within_window? || last_letter_request_too_recent?
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

    def window_limit_enabled?
      IdentityConfig.store.max_mail_events != 0 &&
        IdentityConfig.store.max_mail_events_window_in_days != 0
    end

    def last_not_too_recent_enabled?
      IdentityConfig.store.minimum_wait_before_another_usps_letter_in_hours != 0
    end

    attr_reader :current_user

    def too_many_letter_requests_within_window?
      return false unless window_limit_enabled?

      number_of_letter_requests_within(
        IdentityConfig.store.max_mail_events_window_in_days.days,
        maximum: IdentityConfig.store.max_mail_events,
      ) >= IdentityConfig.store.max_mail_events
    end

    def last_letter_request_too_recent?
      return false unless last_not_too_recent_enabled?
      return false unless current_user.gpo_verification_pending_profile?

      number_of_letter_requests_within(
        IdentityConfig.store.minimum_wait_before_another_usps_letter_in_hours.hours,
        maximum: 1,
        for_profile: current_user.pending_profile,
      ) > 0
    end

    def number_of_letter_requests_within(time_window, maximum:, for_profile: nil)
      profile_query_conditions = { user: current_user }
      profile_query_conditions[:id] = for_profile.id if for_profile

      GpoConfirmationCode.joins(:profile).
        where(
          updated_at: (time_window.ago..),
          profile: profile_query_conditions,
        ).
        limit(maximum).
        count
    end
  end
end
