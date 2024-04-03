# frozen_string_literal: true

# Parses duration strings ("1d", 2w", "3m", "4y" into ActiveSupport::Durations)
class DurationParser
  attr_reader :value

  # @param value [String, nil]
  def initialize(value)
    @value = value
  end

  # @return [ActiveSupport::Duration, nil]
  def parse
    return if value.blank?

    match = value.match(/^(?<number>\d+)(?<duration>\D)$/)
    return nil unless match

    parse_duration(Integer(match[:number], 10), match[:duration])
  rescue ArgumentError
    nil
  end

  def valid?
    value.blank? || !parse.nil?
  end

  # @api private
  def parse_duration(number, duration)
    case duration
    when 'd' # days
      number.days
    when 'w' # weeks
      (7 * number).days
    when 'm' # months
      (30 * number).days
    when 'y' # years
      (365 * number).days
    end
  end
end
