class IrsAttemptApiLogFile < ApplicationRecord
end

# == Schema Information
#
# Table name: irs_attempt_api_log_files
#
#  id             :bigint           not null, primary key
#  encrypted_key  :text
#  filename       :string
#  iv             :string
#  requested_time :datetime
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#
# Indexes
#
#  index_irs_attempt_api_log_files_on_requested_time  (requested_time)
#
