# frozen_string_literal: true

class DeviceProfilingResult < ApplicationRecord
  belongs_to :user
  
  # Check if a user has passed device profiling
  def self.passed?(user_id:, type:)
    result = find_by(user_id: user_id)
    result && result.success?
  end
  
  # Check if a user has failed device profiling
  def self.failed?(user_id:, type:)
    result = find_by(user_id: user_id)
    result && !result.success?
  end
  
  # Check if a user has been automatically rejected
  def self.auto_rejected?(user_id:, type:)
    result = find_by(user_id: user_id)
    result && result.review_status == 'reject'
  end
  
  # Get the result for a user, or nil if no result exists
  def self.for_user(user_id)
    where(user_id: user_id)
  end
end