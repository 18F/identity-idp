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

    unless (match = value.match(/^(?<number>\d+)(?<duration>\D)$/))
      return nil
    end

    number = Integer(match[:number], 10)

    case match[:duration]
    when 'd' # days
      number.days
    when 'w' # weeks
      (7 * number).days
    when 'm' # months
      (30 * number).days
    when 'y' # years
      (365 * number).days
    else
      nil
    end
  rescue ArgumentError
    nil
  end

  def valid?
    !value.present? || !!parse
  end
end
