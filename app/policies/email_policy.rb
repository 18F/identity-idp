class EmailPolicy
  def initialize(user)
    @user = EmailContext.new(user)
  end

  def can_delete_email?(email)
    return false if email.confirmed? && last_confirmed_email_address?
    return false if last_email_address?
    true
  end

  def can_add_email?
    user.email_address_count < Figaro.env.max_emails_per_account.to_i
  end

  private

  def last_confirmed_email_address?
    user.confirmed_email_address_count <= 1
  end

  def last_email_address?
    user.email_address_count <= 1
  end

  attr_reader :user
end
