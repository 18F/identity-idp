class LetterRequestsToUspsFtpLog < ApplicationRecord
  validates :ftp_at, presence: true
  validates :letter_requests_count, presence: true
end
