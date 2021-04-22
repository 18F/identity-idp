class SendExpiredLetterNotifications
  def call
    notifications_sent = 0
    GpoConfirmationCode.where(
      'created_at < ?', Time.zone.now - IdentityConfig.store.usps_confirmation_max_days.days
    ).where(bounced_at: nil, letter_expired_sent_at: nil).
      order(created_at: :asc).each do |gpo_confirmation_code|
      mark_sent_and_send_email(gpo_confirmation_code)
      notifications_sent += 1
    end
    notifications_sent
  end

  private

  def mark_sent_and_send_email(gpo_confirmation_code)
    user = gpo_confirmation_code.profile.user
    mark_sent(gpo_confirmation_code)
    user.confirmed_email_addresses.each do |email_address|
      UserMailer.letter_expired(user, email_address.email).deliver_now
    end
  end

  def mark_sent(gpo_confirmation_code)
    gpo_confirmation_code.letter_expired_sent_at = Time.zone.now
    gpo_confirmation_code.save!
  end
end
