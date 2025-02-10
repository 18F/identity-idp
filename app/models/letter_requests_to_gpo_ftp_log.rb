# frozen_string_literal: true

class LetterRequestsToGpoFtpLog < ApplicationRecord
  self.table_name = 'letter_requests_to_usps_ftp_logs'

  validates :ftp_at, presence: true
  validates :letter_requests_count, presence: true
end
