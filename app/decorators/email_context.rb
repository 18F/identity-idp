class EmailContext
  attr_reader :user

  def initialize(user)
    @user = user
  end

  def last_sign_in_email_address
    user.confirmed_email_addresses.order('last_sign_in_at DESC NULLS LAST').first
  end
end
