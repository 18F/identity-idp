class ApplicationJob < ActiveJob::Base
  self.log_arguments = false
  # Automatically retry jobs that encountered a deadlock
  # retry_on ActiveRecord::Deadlocked

  # Most jobs are safe to ignore if the underlying records are no longer available
  # discard_on ActiveJob::DeserializationError

  # Helper to round a Time instance to a particular interval
  # @param [Time] time
  # @param [Integer] interval number of seconds to round to
  # @return [Time]
  # @example
  #  round_time(time: Time.zone.now, interval: 5.minutes)
  def self.round_time(time:, interval:)
    rounded_seconds = (time.to_i / interval.to_i) * interval.to_i
    Time.zone.at(rounded_seconds)
  end
end
