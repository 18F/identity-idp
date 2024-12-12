# frozen_string_literal: true

module Idv
  class GpoVerifyByMailPolicy
    attr_reader :user, :resolved_authn_context_result

    def initialize(user, resolved_authn_context_result)
      @user = user
      @resolved_authn_context_result = resolved_authn_context_result
    end

    def resend_letter_available?
      @resend_letter_available ||= FeatureManagement.gpo_verification_enabled? &&
                                   !rate_limited? &&
                                   !profile_too_old?
    end

    def send_letter_available?
      @send_letter_available ||= FeatureManagement.gpo_verification_enabled? &&
                                 !disabled_for_facial_match? &&
                                 !disabled_for_ipp? &&
                                 !rate_limited?
    end

    def rate_limited?
      too_many_letter_requests_within_window? || last_letter_request_too_recent?
    end

    def profile_too_old?
      return false if !user.pending_profile

      min_creation_date = IdentityConfig.store
        .gpo_max_profile_age_to_send_letter_in_days.days.ago

      user.pending_profile.created_at < min_creation_date
    end

    private

    def disabled_for_facial_match?
      resolved_authn_context_result.two_pieces_of_fair_evidence?
    end

    def disabled_for_ipp?
      user.has_in_person_enrollment?
    end

    def window_limit_enabled?
      IdentityConfig.store.max_mail_events != 0 &&
        IdentityConfig.store.max_mail_events_window_in_days != 0
    end

    def last_not_too_recent_enabled?
      IdentityConfig.store.minimum_wait_before_another_usps_letter_in_hours != 0
    end

    def too_many_letter_requests_within_window?
      return false unless window_limit_enabled?
      user.gpo_confirmation_codes.where(
        created_at: IdentityConfig.store.max_mail_events_window_in_days.days.ago..Time.zone.now,
      ).count >= IdentityConfig.store.max_mail_events
    end

    def last_letter_request_too_recent?
      return false unless last_not_too_recent_enabled?
      return false unless user.gpo_verification_pending_profile?

      user.gpo_verification_pending_profile.gpo_confirmation_codes.exists?(
        [
          'created_at > ?',
          IdentityConfig.store.minimum_wait_before_another_usps_letter_in_hours.hours.ago,
        ],
      )
    end
  end
end
