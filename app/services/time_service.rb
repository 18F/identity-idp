# frozen_string_literal: true

module TimeService
  # @param [Time] start
  # @param [Time] finish
  # @return [Integer] elapsed whole milliseconds
  def self.duration_ms(start:, finish:)
    ((finish.to_f - start.to_f) * 1000.0).to_i
  end

  # Helper to round a Time instance to a particular interval
  # @param [Time] time
  # @param [Integer] interval number of seconds to round to
  # @return [Time]
  # @example
  #   round_time(time: Time.zone.now, interval: 5.minutes)
  def self.round_time(time:, interval:)
    rounded_seconds = (time.to_i / interval.to_i) * interval.to_i
    Time.zone.at(rounded_seconds)
  end
end
