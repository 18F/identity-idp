# frozen_string_literal: true

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
    delete_identity_email_id if success
    FormResponse.new(success: success, errors: errors)
  end

  private

  def email_address_destroyed
    return false unless EmailPolicy.new(@user).can_delete_email?(@email_address)
    return false if email_address.destroy == false
    user.email_addresses.reload
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

  def delete_identity_email_id
    if user.identities.present?
      user.identities.where(email_address_id: email_address.id).each do |identity|
        identity.email_address_id = nil
        identity.save
      end
    end
  end
end
