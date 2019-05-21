class EmailContext
  attr_reader :user

  def initialize(user)
    @user = user
  end

  def last_sign_in_email_address
    user.confirmed_email_addresses.order('last_sign_in_at DESC NULLS LAST').first
  end

  def email_address_count
    user.email_addresses.count
  end

  def confirmed_email_address_count
    user.confirmed_email_addresses.count
  end
end
