class ForbiddenPasswords
  def initialize(email)
    @email = email
  end

  def call
    [email, split_email(email), APP_NAME].flatten unless email.nil?
  end

  private

  attr_reader :email

  def split_email(email_address)
    email_address.split(/[[:^word:]_]/)
  end
end
