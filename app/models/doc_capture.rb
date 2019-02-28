class DocCapture < ApplicationRecord
  belongs_to :user

  def expired?
    requested_at + Figaro.env.doc_capture_request_valid_for_minutes.to_i.minutes < Time.zone.now
  end
end
