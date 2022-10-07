class SendAddEmailConfirmation
  attr_reader :user

  def initialize(user)
    @user = user
  end

  def call(email_address)
    @email_address = email_address
    update_email_address_record
    send_email
  end

  private

  def confirmation_token
    email_address.confirmation_token
  end

  def confirmation_sent_at
    email_address.confirmation_sent_at
  end

  attr_reader :email_address

  def update_email_address_record
    email_address.update!(
      confirmation_token: confirmation_token,
      confirmation_sent_at: confirmation_sent_at,
    )
  end

  def already_confirmed_by_another_user?
    EmailAddress.where(
      email_fingerprint: Pii::Fingerprinter.fingerprint(email_address.email),
    ).where.not(confirmed_at: nil).
      where.not(user_id: email_address.user_id).
      first
  end

  def send_email
    if already_confirmed_by_another_user?
      send_email_associated_with_another_account_email
    else
      send_confirmation_email
    end
  end

  def send_email_associated_with_another_account_email
    UserMailer.add_email_associated_with_another_account(
      email_address.email,
    ).deliver_now_or_later
  end

  def send_confirmation_email
    UserMailer.with(user: user, email_address: email_address).add_email(
      confirmation_token,
    ).deliver_now_or_later
  end
end
