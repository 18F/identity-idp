class HolidayService
  # https://www.opm.gov/policy-data-oversight/snow-dismissal-procedures/federal-holidays

  class << self
    def holiday?(date)
      new(date.year).holiday?(date)
    end

    def observed_holiday?(date)
      new(date.year).observed_holiday?(date)
    end
  end

  attr_reader :year

  def initialize(year)
    @year = year
  end

  def holiday?(date)
    holidays.any? { |holiday| holiday == date }
  end

  def observed_holiday?(date)
    observed_holidays.any? { |oh| oh == date }
  end

  # rubocop:disable Metrics/MethodLength
  def holidays
    [
      new_years,
      mlk,
      washington,
      memorial,
      independence,
      labor,
      columbus,
      veterans,
      thanksgiving,
      christmas,
    ]
  end
  # rubocop:enable Metrics/MethodLength

  def observed_holidays
    holidays.
      concat([next_new_years]).
      map(&method(:observed)).
      select { |oh| oh.year == year }
  end

  # January 1st
  def new_years
    Date.new(year, 1, 1)
  end

  # 3rd Monday of January
  def mlk
    Date.new(year, 1, 1).
      step(Date.new(year, 2, 1)).
      select(&:monday?)[2]
  end

  # 3rd Monday of February
  def washington
    Date.new(year, 2, 1).
      step(Date.new(year, 3, 1)).
      select(&:monday?)[2]
  end

  # Last Monday of May
  def memorial
    Date.new(year, 6, 1).
      step(Date.new(year, 5, 1), -1).
      find(&:monday?)
  end

  # July 4th
  def independence
    Date.new(year, 7, 4)
  end

  # First Monday of September
  def labor
    Date.new(year, 9, 1).
      step(Date.new(year, 10, 1)).
      find(&:monday?)
  end

  # Second Monday of October
  def columbus
    Date.new(year, 10, 1).
      step(Date.new(year, 11, 1)).
      select(&:monday?).second
  end

  # November 11th
  def veterans
    Date.new(year, 11, 11)
  end

  # 4th Thursday of November
  def thanksgiving
    Date.new(year, 11, 1).
      step(Date.new(year, 12, 1)).
      select(&:thursday?)[3]
  end

  # December 25th
  def christmas
    Date.new(year, 12, 25)
  end

  # If NY is on a Saturday, the observed holiday would be in the prior year,
  # make sure to include it in observed holidays when necessary
  def next_new_years
    Date.new(year + 1, 1, 1)
  end

  private

  def observed(date)
    return date - 1 if date.saturday?
    return date + 1 if date.sunday?
    date
  end
end
