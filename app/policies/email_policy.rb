# frozen_string_literal: true

class EmailPolicy
  def initialize(user)
    @user = user
  end

  def can_delete_email?(email)
    return false if email.confirmed? && last_confirmed_email_address?
    return false if last_email_address?
    true
  end

  def can_add_email?
    user.email_addresses.count < IdentityConfig.store.max_emails_per_account
  end

  private

  def last_confirmed_email_address?
    user.confirmed_email_addresses.count <= 1
  end

  def last_email_address?
    user.email_addresses.count <= 1
  end

  attr_reader :user
end
