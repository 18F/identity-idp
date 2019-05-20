class EmailPolicy
  def initialize(user)
    @user = EmailContext.new(user)
  end

  def can_delete_email?
    user.email_address_count > 1
  end

  private

  attr_reader :user
end
