# frozen_string_literal: true

class DeviceProfilingResult < ApplicationRecord
  belongs_to :user

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

  def self.for_user(user_id:, type:)
    where(user_id:, profiling_type: type)
  end

  def rejected?
    review_status == 'reject'
  end
end
