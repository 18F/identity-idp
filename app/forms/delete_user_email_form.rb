class DeleteUserEmailForm
  include ActiveModel::Model

  attr_reader :user, :email_address

  validates :email_address, allow_nil: true, owned_by_user: true

  def initialize(user, email_address)
    @user = user
    @email_address = email_address
  end

  def submit
    success = valid? && email_address_destroyed
    FormResponse.new(success: success, errors: errors.messages)
  end

  private

  def email_address_destroyed
    return false unless EmailPolicy.new(@user).can_delete_email?
    return false if email_address.destroy == false
    user.email_addresses.reload
    true
  end
end
