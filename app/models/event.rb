class Event < ApplicationRecord
  belongs_to :user
  belongs_to :device

  enum event_type: {
    account_created: 1,
    phone_confirmed: 2,
    password_changed: 3,
    phone_changed: 4,
    email_changed: 5,
    authenticator_enabled: 6,
    authenticator_disabled: 7,
    account_verified: 8,
    gpo_mail_sent: 9,
    piv_cac_enabled: 10,
    piv_cac_disabled: 11,
    new_personal_key: 12,
    personal_key_used: 13,
    webauthn_key_added: 14,
    webauthn_key_removed: 15,
    phone_removed: 16,
    backup_codes_added: 17,
    sign_in_before_2fa: 18,
    sign_in_after_2fa: 19,
    email_deleted: 20,
    phone_added: 21,
    password_invalidated: 22,
  }

  validates :event_type, presence: true

  def decorate
    EventDecorator.new(self)
  end
end

# rubocop:disable Layout/LineLength
# == Schema Information
#
# Table name: events
#
#  id                          :integer          not null, primary key
#  disavowal_token_fingerprint :string
#  disavowed_at                :datetime
#  event_type                  :integer          not null
#  ip                          :string
#  created_at                  :datetime         not null
#  updated_at                  :datetime         not null
#  device_id                   :integer
#  user_id                     :integer          not null
#
# Indexes
#
#  index_events_on_device_id_and_created_at     (device_id,created_at)
#  index_events_on_disavowal_token_fingerprint  (disavowal_token_fingerprint)
#  index_events_on_user_id_and_created_at       (user_id,created_at)
#
# rubocop:enable Layout/LineLength
