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
    notify_subscribers if success
    FormResponse.new(success: success, errors: errors)
  end

  private

  # When the user deletes an email address, we need to make sure we update the email columns on the
  # user model with the values from an email address record to make sure they are not occupied by
  # the email address the user deleted
  #
  # In order to do this, we need to update the columns without running the callbacks. Running the
  # callback will cause the code that updates the email address table when there are changes to
  # the user model to run
  #
  # rubocop:disable Rails/SkipsModelValidations
  def update_user_email_column
    new_email_address = user.confirmed_email_addresses.take
    user.update_columns(
      encrypted_email: new_email_address.encrypted_email,
      email_fingerprint: new_email_address.email_fingerprint,
    )
  end
  # rubocop:enable Rails/SkipsModelValidations

  def email_address_destroyed
    return false unless EmailPolicy.new(@user).can_delete_email?(@email_address)
    return false if email_address.destroy == false
    user.email_addresses.reload
    update_user_email_column
    true
  end

  def notify_subscribers
    email = email_address.email
    identifier_recycled = PushNotification::IdentifierRecycledEvent.new(user: user, email: email)
    PushNotification::HttpPush.deliver(identifier_recycled)
    email_changed = PushNotification::EmailChangedEvent.new(user: user, email: email)
    PushNotification::HttpPush.deliver(email_changed)
    recovery_information_changed = PushNotification::RecoveryInformationChangedEvent.new(user: user)
    PushNotification::HttpPush.deliver(recovery_information_changed)
  end
end
