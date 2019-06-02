class SendAddEmailConfirmation
  attr_reader :user

  def initialize(user)
    @user = user
  end

  def call
    update_email_address_record
    send_confirmation_email
  end

  private

  def confirmation_token
    email_address.confirmation_token
  end

  def confirmation_sent_at
    email_address.confirmation_sent_at
  end

  def confirmation_period_expired?
    @confirmation_period_expired ||= user.confirmation_period_expired?
  end

  def email_address
    @email_address ||= begin
      user.email_addresses.take
    end
  end

  def valid_confirmation_token_exists?
    email_address.confirmation_token.present? && !confirmation_period_expired?
  end

  def update_email_address_record
    email_address.update!(
      confirmation_token: confirmation_token,
      confirmation_sent_at: confirmation_sent_at,
    )
  end

  def send_confirmation_email
    UserMailer.add_email(
      user,
      email_address.email,
      confirmation_token,
    ).deliver_later
  end
end
