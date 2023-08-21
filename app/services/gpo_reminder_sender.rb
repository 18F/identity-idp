class GpoReminderSender
  def initialize(analytics)
    @analytics = analytics
  end

  def send_emails(for_letters_sent_before)
    profiles_due_for_reminder = Profile.joins(:gpo_confirmation_codes).
      where(
        gpo_verification_pending_at: ..for_letters_sent_before,
        gpo_confirmation_codes: { reminder_sent_at: nil },
      )

    profiles_due_for_reminder.each do |profile|
      profile.user.send_email_to_all_addresses(:gpo_reminder)
      @analytics.idv_gpo_reminder_email_sent(user_id: profile.user.uuid)
    end
  end
end
