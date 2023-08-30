class GpoReminderSender
  def send_emails(for_letters_sent_before)
    letter_eligible_range =
      IdentityConfig.store.usps_confirmation_max_days.days.ago..for_letters_sent_before

    profiles_due_for_reminder = Profile.joins(:gpo_confirmation_codes).
      where(
        gpo_verification_pending_at: letter_eligible_range,
        gpo_confirmation_codes: { reminder_sent_at: nil },
        deactivation_reason: [nil, :in_person_verification_pending],
      )

    profiles_due_for_reminder.each do |profile|
      profile.user.send_email_to_all_addresses(:gpo_reminder)
      profile.gpo_confirmation_codes.first.update(reminder_sent_at: Time.zone.now)
      analytics.idv_gpo_reminder_email_sent(user_id: profile.user.uuid)
    end
  end

  private

  def analytics
    Analytics.new(user: AnonymousUser.new, request: nil, session: {}, sp: nil)
  end
end
