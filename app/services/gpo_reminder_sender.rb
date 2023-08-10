class GpoReminderSender
  def send_emails
    Profile.where.not(gpo_verification_pending_at: nil).each do |profile|
      profile.user.send_email_to_all_addresses(:gpo_reminder)
    end
  end
end
