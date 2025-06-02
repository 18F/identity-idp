# frozen_string_literal: true

class DeviceProfilingResult < ApplicationRecord
  belongs_to :user, dependent: :destroy

  PROFILING_TYPES = {
    account_creation: 'ACCOUNT_CREATION',
  }.freeze

  def self.find_or_create_by(user_id:, profiling_type:)
    obj = find_by(user_id:, profiling_type:)
    return obj if obj
    create(
      user_id:,
      profiling_type:,
    )
  end

  def self.passed?(user_id:, type:)
    result = find_by(user_id:, profiling_type: type)
    result&.success?
  end

  def self.failed?(user_id:, type:)
    result = find_by(user_id:, profiling_type: type)
    result && (result.review_status != 'pass')
  end

  def self.auto_rejected?(user_id:, type:)
    result = find_by(user_id:, profiling_type: type)
    result && result.review_status == 'reject'
  end

  # Get the result for a user, or nil if no result exists
  def self.for_user(user_id:, type:)
    where(user_id:, profiling_type: type)
  end

  def rejected?
    review_status != 'pass'
  end
end
