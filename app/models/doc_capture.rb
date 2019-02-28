class DocCapture < ApplicationRecord
  belongs_to :user
  validates :user_id, presence: true
  validates :request_token, presence: true
  validates :requested_at, presence: true

  def expired?
    requested_at + Figaro.env.doc_capture_request_valid_for_minutes.to_i.minutes < Time.zone.now
  end
end
