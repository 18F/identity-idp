# frozen_string_literal: true

module Idv
  module VerifyByMailConcern
    def gpo_verify_by_mail_policy
      @gpo_verify_by_mail_policy ||= Idv::GpoVerifyByMailPolicy.new(
        current_user,
        resolved_authn_context_result,
      )
    end

    def log_letter_requested_analytics(resend:)
      analytics.idv_gpo_address_letter_requested(
        resend: resend,
        first_letter_requested_at: first_letter_requested_at,
        hours_since_first_letter: hours_since_first_letter,
        phone_step_attempts: phone_step_attempt_count,
        **ab_test_analytics_buckets,
      )
    end

    def log_letter_enqueued_analytics(resend:)
      analytics.idv_gpo_address_letter_enqueued(
        enqueued_at: Time.zone.now,
        resend: resend,
        phone_step_attempts: phone_step_attempt_count,
        first_letter_requested_at: first_letter_requested_at,
        hours_since_first_letter: hours_since_first_letter,
        **ab_test_analytics_buckets,
      )
    end

    def phone_step_attempt_count
      @phone_step_attempt_count ||= RateLimiter.new(
        user: current_user,
        rate_limit_type: :proof_address,
      ).attempts
    end

    def first_letter_requested_at
      current_user.gpo_verification_pending_profile&.gpo_verification_pending_at
    end

    def hours_since_first_letter
      if first_letter_requested_at.present?
        (Time.zone.now - first_letter_requested_at).to_i.seconds.in_hours.to_i
      else
        0
      end
    end
  end
end
