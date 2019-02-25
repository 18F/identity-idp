class ExpiredLetters
  def call
    notifications_sent = 0
    UspsConfirmationCode.where(
      sql_query_for_expired_letters,
      tvalue: Time.zone.now - Figaro.env.usps_confirmation_max_days.to_i.days,
    ).order('created_at ASC').each do |ucc|
      mark_sent_and_send_email(ucc)
      notifications_sent += 1
    end
    notifications_sent
  end

  private

  def sql_query_for_expired_letters
    <<~SQL
      bounced_at IS NULL AND
      letter_expired_sent_at IS NULL AND
      created_at < :tvalue AND
    SQL
  end

  def mark_sent_and_send_email(ucc)
    user = ucc.profile.user
    mark_sent(ucc)
    user.confirmed_email_addresses.each do |email_address|
      UserMailer.letter_expired(email_address, arr).deliver_later
    end
  end

  def mark_sent(ucc)
    ucc.letter_expired_sent_at = Time.zone.now
    ucc.save!
  end
end
