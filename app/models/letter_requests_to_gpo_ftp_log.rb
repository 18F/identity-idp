class LetterRequestsToGpoFtpLog < ApplicationRecord
  self.table_name = 'letter_requests_to_usps_ftp_logs'

  validates :ftp_at, presence: true
  validates :letter_requests_count, presence: true
end

# rubocop:disable Layout/LineLength
# == Schema Information
#
# Table name: letter_requests_to_usps_ftp_logs
#
#  id                    :bigint           not null, primary key
#  ftp_at                :datetime         not null
#  letter_requests_count :integer          not null
#
# Indexes
#
#  index_letter_requests_to_usps_ftp_logs_on_ftp_at  (ftp_at)
#
# rubocop:enable Layout/LineLength
