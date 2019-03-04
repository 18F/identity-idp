class SendExpiredLetterNotifications
  def call
    notifications_sent = 0
    UspsConfirmationCode.where(
      'created_at < ?', Time.zone.now - Figaro.env.usps_confirmation_max_days.to_i.days
    ).where(bounced_at: nil, letter_expired_sent_at: nil).
      order(created_at: :asc).each do |usps_confirmation_code|
      mark_sent_and_send_email(usps_confirmation_code)
      notifications_sent += 1
    end
    notifications_sent
  end

  private

  def mark_sent_and_send_email(usps_confirmation_code)
    user = usps_confirmation_code.profile.user
    mark_sent(usps_confirmation_code)
    user.confirmed_email_addresses.each do |email_address|
      UserMailer.letter_expired(email_address.email).deliver_later
    end
  end

  def mark_sent(usps_confirmation_code)
    usps_confirmation_code.letter_expired_sent_at = Time.zone.now
    usps_confirmation_code.save!
  end
end
