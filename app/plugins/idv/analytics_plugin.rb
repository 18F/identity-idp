module Idv
  class AnalyticsPlugin < BasePlugin
    on_step_started :request_letter do |analytics:, resend_requested:, **rest|
      analytics.idv_request_letter_visited(
        letter_already_sent: resend_requested,
      )
    end

    on_step_completed :request_letter do |
      analytics:,
      letter_enqueued:,
      resend_requested:,
      user:, **rest
    |
      gpo_mail_service = Idv::GpoMail.new(user)
      first_letter_requested_at = user.gpo_verification_pending_profile&.gpo_verification_pending_at
      hours_since_first_letter = gpo_mail_service.hours_since_first_letter(
        first_letter_requested_at,
      )

      analytics.idv_gpo_address_letter_requested(
        resend: resend_requested?,
        first_letter_requested_at: first_letter_requested_at,
        hours_since_first_letter: hours_since_first_letter,
        phone_step_attempts: gpo_mail_service.phone_step_attempts,
        # TODO: A/B test analytics buckets
        # **ab_test_analytics_buckets,
      )

      if letter_enqueued
        analytics.idv_gpo_address_letter_enqueued(
          enqueued_at: Time.zone.now,
          resend: true,
          first_letter_requested_at: first_letter_requested_at,
          hours_since_first_letter: hours_since_first_letter,
          phone_step_attempts: gpo_mail_service.phone_step_attempts,
          # TODO: A/B test analytics buckets
          # **ab_test_analytics_buckets,
        )
      end
    end
  end
end
