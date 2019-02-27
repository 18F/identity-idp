class SendExpiredLetterNotifications
  def call
    notifications_sent = 0
    UspsConfirmationCode.where(
      'created_at < ?', Time.zone.now - Figaro.env.usps_confirmation_max_days.to_i.days
    ).where(bounced_at: nil, letter_expired_sent_at: nil).order(created_at: :asc).each do |ucc|
      mark_sent_and_send_email(ucc)
      notifications_sent += 1
    end
    notifications_sent
  end

  private

  def mark_sent_and_send_email(ucc)
    user = ucc.profile.user
    mark_sent(ucc)
    user.confirmed_email_addresses.each do |email_address|
      UserMailer.letter_expired(email_address.email).deliver_later
    end
  end

  def mark_sent(ucc)
    ucc.letter_expired_sent_at = Time.zone.now
    ucc.save!
  end
end
