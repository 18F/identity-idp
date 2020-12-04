class IsWeekendOrHoliday
  def self.call(date)
    IsWeekend.call(date) || HolidayService.observed_holiday?(date)
  end
end
