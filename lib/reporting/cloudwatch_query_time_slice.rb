# frozen_string_literal: true

module Reporting
  module CloudwatchQueryTimeSlice
    # @param [String] value a string such as 1min, 2h, 3d, 4w, 5mon, 6y
    # @return [ActiveSupport::Duration]
    def self.parse_duration(value)
      if (match = value.match(/^(?<number>\d+)(?<unit>\D+)$/))
        number = Integer(match[:number], 10)

        duration = case match[:unit]
        when 'min'
          number.minutes
        when 'h'
          number.hours
        when 'd'
          number.days
        when 'w'
          number.weeks
        when 'mon'
          number.months
        when 'y'
          number.years
        end

        return duration if duration
      end
    end
  end
end
