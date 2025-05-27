# frozen_string_literal: true

class DeviceProfilingResult < ApplicationRecord
  belongs_to :user, dependent: :destroy

  PROFILING_TYPES= {
    :account_creation => 'ACCOUNT_CREATION'
  }

  def self.passed?(user_id:, type:)
    result = find_by(user_id:, profiling_type: type)
    result && result.success?
  end
  
  def self.failed?(user_id:, type:)
    result = find_by(user_id:, profiling_type: type)
    binding.pry
    result && !result.success?
  end


  def self.auto_rejected?(user_id:, type:)
    result = find_by(user_id:, profiling_type: type)
    result && result.review_status == 'reject'
  end
  
  # Get the result for a user, or nil if no result exists
  def self.for_user(user_id)
    where(user_id: user_id)
  end
end