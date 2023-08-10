class GpoReminderSender
  def send_emails
    profiles = Profile# joins(:usps_confirmation_codes)
                 .where(gpo_verification_pending_at: ..(Time.zone.now - 14.days))
                 # .where(reminder_sent_at: nil)

    profiles.each do |profile|
      profile.user.send_email_to_all_addresses(:gpo_reminder)
    end
  end
end
