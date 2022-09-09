module Reports
  module MonthHelper
    module_function

    # Takes a date range and breaks it into an array of ranges by month. The first and last items
    # may be partial months (ex starting in the middle and ending at the end) and the intermediate
    # items are always full months (1st to last of month)
    # @example
    #   months(Date.new(2021, 3, 15)..Date.new(2021, 5, 14))
    #   => [
    #     Time.new(2021, 3, 15, 0, 0, 0)..Time.new(2021, 3, 31, 23, 59, 59),
    #     Time.new(2021, 4, 1, 0, 0, 0)..Time.new(2021, 4, 30, 23, 59, 59),
    #     Time.new(2021, 5, 1, 0, 0, 0)..Time.new(2021, 5, 14, 23, 59, 59),
    #   ]
    # @param [Range<Date>] date_range
    # @return [Array<Range<Time>>]
    def months(date_range)
      time_range = Range.new(
        date_range.begin.in_time_zone('UTC').beginning_of_day,
        date_range.end.in_time_zone('UTC').end_of_day,
      )

      results = []

      results << (time_range.begin..time_range.begin.end_of_month)

      current = time_range.begin.end_of_month + 1.day
      while current < time_range.end.beginning_of_month
        month_start = current.beginning_of_month
        month_end = current.end_of_month

        results << (month_start..month_end)

        current = month_end + 1.day
      end

      results << (time_range.end.beginning_of_month..time_range.end)

      results
    end
  end
end
