# frozen_string_literal: true

class DeviceProfilingResult < ApplicationRecord
  belongs_to :user

  PROFILING_TYPES = {
    account_creation: 'ACCOUNT_CREATION',
  }.freeze
end
