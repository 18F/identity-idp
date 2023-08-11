class GpoReminderSender
  def send_emails
    profiles_due_for_reminder = Profile.joins(:gpo_confirmation_codes).
      where(
        gpo_verification_pending_at: ..(Time.zone.now - 14.days),
        gpo_confirmation_codes: { reminder_sent_at: nil },
      )
    profiles_due_for_reminder.each do |profile|
      profile.user.send_email_to_all_addresses(:gpo_reminder)
    end
  end
end
