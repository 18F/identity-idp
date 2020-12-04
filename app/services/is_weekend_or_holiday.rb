class IsWeekendOrHoliday
  def self.call(date)
    IsWeekend.call(date) || CalendarService.observed_holiday?(date)
  end
end
