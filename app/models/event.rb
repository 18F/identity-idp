class Event < ApplicationRecord
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
    usps_mail_sent: 9,
    piv_cac_enabled: 10,
    piv_cac_disabled: 11,
  }

  validates :event_type, presence: true

  def decorate
    EventDecorator.new(self)
  end
end
