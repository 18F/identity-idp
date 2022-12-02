# == Schema Information
#
# Table name: registration_logs
#
#  id            :bigint           not null, primary key
#  registered_at :datetime
#  user_id       :integer          not null
#
# Indexes
#
#  index_registration_logs_on_registered_at  (registered_at)
#  index_registration_logs_on_user_id        (user_id) UNIQUE
#
class RegistrationLog < ApplicationRecord
  belongs_to :user
end
