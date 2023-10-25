# frozen_string_literal: true

class ApplicationJob < ActiveJob::Base
  self.log_arguments = false
  # Automatically retry jobs that encountered a deadlock
  # retry_on ActiveRecord::Deadlocked

  # Most jobs are safe to ignore if the underlying records are no longer available
  # discard_on ActiveJob::DeserializationError

  def self.warning_error_classes
    []
  end
end
