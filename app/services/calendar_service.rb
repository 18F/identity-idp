class CalendarService
  # https://www.opm.gov/policy-data-oversight/snow-dismissal-procedures/federal-holidays

  class << self
    def holiday?(date)
      new(date.year).holiday?(date)
    end

    def observed_holiday?(date)
      new(date.year).observed_holiday?(date)
    end

    def weekend?(date)
      date.saturday? || date.sunday?
    end

    def weekend_or_holiday?(date)
      weekend?(date) || holiday?(date)
    end

    def fiscal_start_date(date)
      date.change(year: date.month >= 10 ? date.year : date.year - 1, month: 10, day: 1)
    end

    def fiscal_q2_start(date)
      date.change(year: date.month >= 10 ? date.year + 1: date.year, month: 1, day: 1)
    end

    def fiscal_q3_start(date)
      date.change(year: date.month >= 10 ? date.year + 1: date.year, month: 4, day: 1)
    end

    def fiscal_q4_start(date)
      date.change(year: date.month >= 10 ? date.year + 1: date.year, month: 7, day: 1)
    end

    def fiscal_end_date(date)
      date.change(year: date.month >= 10 ? date.year + 1 : date.year, month: 9, day: 30)
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

  def holidays
    [
      new_years,
      mlk,
      washington,
      memorial,
      juneteenth,
      independence,
      labor,
      columbus,
      veterans,
      thanksgiving,
      christmas,
    ]
  end

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

  # June 19th
  def juneteenth
    Date.new(year, 6, 19)
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
