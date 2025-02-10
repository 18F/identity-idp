# frozen_string_literal: true

class GpoReminderSender
  LOCAL_DATABASE_TIMEOUT = 60_000

  def send_emails(for_letters_sent_before)
    reminder_eligible_range =
      IdentityConfig.store.usps_confirmation_max_days.days.ago..for_letters_sent_before
    profiles_due_for_reminder(for_letters_sent_before).each do |profile|
      next if profile.user.active_profile
      profile.gpo_confirmation_codes.find_each do |gpo_code|
        next if gpo_code.reminder_sent_at
        next unless reminder_eligible_range.cover?(gpo_code.created_at)

        # Only email the user if we have an eligible code.
        # Unlikely to have multiple codes since we only allow one letter/day
        # due to config setting: minimum_wait_before_another_usps_letter_in_hours
        profile.user.send_email_to_all_addresses(:verify_by_mail_reminder)
        analytics.idv_gpo_reminder_email_sent(user_id: profile.user.uuid)
        gpo_code.update(reminder_sent_at: Time.zone.now)
      end
    end
  end

  private

  def profiles_due_for_reminder(for_letters_sent_before)
    ActiveRecord::Base.transaction do
      ActiveRecord::Base.connection.execute(
        "SET LOCAL statement_timeout = #{LOCAL_DATABASE_TIMEOUT}",
      )

      profile_eligible_range =
        (IdentityConfig.store.usps_confirmation_max_days +
          IdentityConfig.store.gpo_max_profile_age_to_send_letter_in_days)
          .days.ago..for_letters_sent_before
      Profile.joins(:gpo_confirmation_codes)
        .where(
          gpo_verification_pending_at: profile_eligible_range,
          gpo_confirmation_codes: { reminder_sent_at: nil },
          deactivation_reason: nil,
        )
    end
  end

  def analytics
    Analytics.new(user: AnonymousUser.new, request: nil, session: {}, sp: nil)
  end
end
