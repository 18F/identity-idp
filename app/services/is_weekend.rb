class IsWeekend
  def self.call(date)
    date.saturday? || date.sunday?
  end
end
