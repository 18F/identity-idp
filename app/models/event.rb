class Event < ActiveRecord::Base
  belongs_to :user

  enum event_type: {
    account_created: 1,
    phone_confirmed: 2,
    password_changed: 3,
    phone_changed: 4,
    email_changed: 5,
    authenticator_enabled: 6,
    authenticator_disabled: 7,
    account_verified: 8,
  }

  validates :event_type, presence: true

  def decorate
    EventDecorator.new(self)
  end
end
