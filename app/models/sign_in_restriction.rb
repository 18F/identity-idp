# == Schema Information
#
# Table name: sign_in_restrictions
#
#  id               :bigint           not null, primary key
#  service_provider :string
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#  user_id          :integer          not null
#
# Indexes
#
#  index_sign_in_restrictions_on_user_id_and_service_provider  (user_id,service_provider) UNIQUE
#
class SignInRestriction < ApplicationRecord
  belongs_to :user
end
