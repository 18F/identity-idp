module Reports
  module MonthHelper
    module_function

    # Takes a date range and breaks it into an array of ranges by month. The first and last items
    # may be partial months (ex starting in the middle and ending at the end) and the intermediate
    # items are always full months (1st to last of month)
    # @example
    #   months(Date.new(2021, 3, 15)..Date.new(2021, 5, 15))
    #   => [
    #     Date.new(2021, 3, 15)..Date.new(2021, 3, 31),
    #     Date.new(2021, 4, 1)..Date.new(2021, 4, 30),
    #     Date.new(2021, 5, 1)..Date.new(2021, 5, 15),
    #   ]
    # @param [Range<Date>] date_range
    # @return [Array<Range<Date>>]
    def months(date_range)
      results = []

      results << (date_range.begin..date_range.begin.end_of_month)

      current = date_range.begin.end_of_month + 1.day
      while current < date_range.end.beginning_of_month
        month_start = current.beginning_of_month
        month_end = current.end_of_month

        results << (month_start..month_end)

        current = month_end + 1.day
      end

      results << (date_range.end.beginning_of_month..date_range.end) if current < date_range.end

      results
    end
  end
end
