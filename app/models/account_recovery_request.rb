class AccountRecoveryRequest < ApplicationRecord
  belongs_to :user
  validates :user_id, presence: true
  validates :request_token, presence: true
  validates :requested_at, presence: true

  def expired?
    validity = Identity::Hostdata.settings.ial2_recovery_request_valid_for_minutes.to_i.minutes
    (requested_at + validity) < Time.zone.now
  end
end
