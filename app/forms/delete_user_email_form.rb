class DeleteUserEmailForm
  include ActiveModel::Model

  attr_reader :user, :email_address

  validates :email_address, allow_nil: true, owned_by_user: true

  def initialize(user, email_address)
    @user = user
    @email_address = email_address
  end

  def submit
    success = email_address.blank? || valid? && email_address_destroyed
    FormResponse.new(success: success, errors: errors.messages)
  end

  private

  def email_address_destroyed
    if email_address.destroy != false
      user.email_addresses.reload
      true
    else
      errors.add(:email_address, :not_destroyed, message: 'cannot remove email')
      false
    end
  end
end
